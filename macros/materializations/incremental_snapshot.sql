{% materialization incremental_snapshot, adapter='bigquery', supported_languages=['sql'] -%}

{%- if var('setup_db', false) -%}
  {%- set target_relation = this -%}
  {%- set language = model['language'] -%}
  {%- call statement('main', language=language) -%}
    {{
        setup_db_for_test(
          config.get('source_data_sql'),
          config.get('target_data_sql'),
          config.get('expected_target_data_sql'),
          config.get('source_name'),
          this,
          config.get('expected_target_table_name'),
          config.get('partition_by', none),
          config.get('cluster_by', none)
        )
    }}
  {%- endcall -%}

  {{ return({'relations': [target_relation]}) }}
{%- elif var('teardown_db', false) -%}
  {%- set target_relation = this -%}
  {%- set language = model['language'] -%}
  {%- call statement('main', language=language) -%}
    {{
        teardown_db(
          config.get('source_name'),
          this,
          config.get('expected_target_table_name'),
          this.project ~ '.' ~ this.schema ~ '.' ~ config.get('temp_source_table'),
          this.project ~ '.' ~ this.schema ~ '.' ~ config.get('temp_target_table')
        )
    }}
  {%- endcall -%}

  {{ return({'relations': [target_relation]}) }}
{%- else -%}
  {%- set unique_key = config.get('unique_key') -%}
  {%- set full_refresh_mode = (should_full_refresh()) -%}
  {%- set language = model['language'] -%}

  {%- set target_relation = this -%}
  {%- set existing_relation = load_relation(this) -%}
  {%- set tmp_relation = make_temp_relation(this) -%}

  {#-- Validate early so we don't run SQL if the strategy is invalid --#}
  {%- set strategy = dbt_bigquery_validate_get_incremental_strategy(config) -%}

  {%- set raw_partition_by = config.get('partition_by', none) -%}
  {%- set partition_by = adapter.parse_partition_by(raw_partition_by) -%}
  {%- set partitions = config.get('partitions', none) -%}
  {%- set cluster_by = config.get('cluster_by', none) -%}

  {%- set on_schema_change = incremental_validate_on_schema_change(config.get('on_schema_change'), default='ignore') -%}
  {%- set incremental_predicates = config.get('predicates', default=none) or config.get('incremental_predicates', default=none) -%}

  {%- set valid_from_col_name = config.get('valid_from_col_name') -%}
  {%- set valid_to_col_name = config.get('valid_to_col_name') -%}
  {%- set source_unique_key = config.get('source_unique_key') -%}

  {%- if source_unique_key is sequence and source_unique_key is not string -%}
    {%- set source_unique_key_cols = source_unique_key -%}
  {%- else -%}
    {%- set source_unique_key_cols = [source_unique_key] -%}
  {%- endif -%}

  {#--
  -- Resolve the window to rebuild.
  --
  -- start: the snapshot_start_date var when the caller gives one. A daily run passes yesterday
  -- and a partial rebuild passes the point to rebuild from.
  --
  -- A full refresh passes nothing and falls back to the model's snapshot_default_start_date,
  -- which is that snapshot's earliest meaningful date. That fallback is deliberately limited to
  -- a full refresh: it is a genesis date, so applying it to an ordinary run would turn a missing
  -- var into a silent rebuild of the entire table -- deleting and recomputing years of history
  -- where one day was intended, and reporting success. An ordinary run with no start date is a
  -- mistake, so it fails instead.
  --
  -- end: always now. The rebuild runs from start to the present, so there is no window to get
  -- wrong and no way to leave the tail of the snapshot inconsistent with its head. It can be
  -- overridden, which the fixtures rely on for a deterministic end.
  --#}
  {%- set requested_start_date = config.get('snapshot_start_date') or var('snapshot_start_date', none) -%}
  {%- set default_start_date = config.get('snapshot_default_start_date', none) -%}
  {%- set start_date = requested_start_date or (default_start_date if full_refresh_mode else none) -%}

  {%- if not start_date -%}
    {%- if full_refresh_mode -%}
      {%- do exceptions.raise_compiler_error(
          "No start date for a full refresh of " ~ this.identifier ~ ". Set "
          ~ "snapshot_default_start_date in the model config to its earliest meaningful date, or "
          ~ "pass an explicit snapshot_start_date var."
      ) -%}
    {%- else -%}
      {%- do exceptions.raise_compiler_error(
          "No start date for " ~ this.identifier ~ ". Pass the snapshot_start_date var. Note that "
          ~ "snapshot_start_date is defined as a project var, so a var(..., 'default') fallback in "
          ~ "the model is never reached -- put the model's own date in snapshot_default_start_date "
          ~ "instead, which a full refresh will use."
      ) -%}
    {%- endif -%}
  {%- endif -%}

  {%- set end_date = config.get('snapshot_end_date')
      or var('snapshot_end_date', none)
      or run_started_at.strftime('%Y-%m-%d') -%}

  {%- set start_date = start_date | string | replace("'", "") | trim -%}
  {%- set end_date = end_date | string | replace("'", "") | trim -%}

  {%- if start_date >= end_date -%}
    {%- do exceptions.raise_compiler_error(
        "Start date " ~ start_date ~ " for " ~ this.identifier ~ " is not before the end of the "
        ~ "rebuild window (" ~ end_date ~ ")."
    ) -%}
  {%- endif -%}

  {%- set chunk_months = config.get('snapshot_chunk_months', var('snapshot_chunk_months', 3)) | int -%}
  {%- set chunk_ranges = stellar_dbt_public.snapshot_chunk_ranges(start_date, end_date, chunk_months) -%}

  {#--
  -- Built once and threaded into every statement that reads or writes the target. Deriving it
  -- again per call site is how an entity nobody asked about gets deleted.
  --#}
  {%- set key_filter = stellar_dbt_public.snapshot_key_filter(source_unique_key_cols) -%}

  {%- if key_filter != '' and target.name == 'prod' -%}
    {%- do exceptions.raise_compiler_error(
        "snapshot_keys deletes and rebuilds rows for the entities it names and must not run "
        ~ "against the prod target"
    ) -%}
  {%- endif -%}

  {%- do log(
      "Rebuilding " ~ this.identifier ~ " from " ~ start_date ~ " to " ~ end_date
      ~ " in " ~ chunk_ranges | length ~ " chunk(s) of " ~ chunk_months ~ " month(s)"
      ~ (" for selected keys only" if key_filter != '' else ""),
      info=true
  ) -%}

  {{ run_hooks(pre_hooks) }}

  {%- set ns = namespace(dest_columns=none, tmp_relation_exists=false, table_exists=(existing_relation is not none)) -%}

  {% if existing_relation is none or full_refresh_mode %}
    {#-- If the partition/cluster config has changed, then we must drop and recreate --#}
    {% if existing_relation and not adapter.is_replaceable(existing_relation, partition_by, cluster_by) %}
      {% do log("Hard refreshing " ~ existing_relation ~ " because it is not replaceable") %}
      {{ adapter.drop_relation(existing_relation) }}
    {% endif %}
    {#-- The first chunk replaces the table outright, so there is nothing to reset. --#}
    {%- set ns.table_exists = false -%}

  {% else %}
    {#--
    -- Return the target to its state at start_date before rebuilding, so the run is
    -- reproducible no matter what a previous attempt left behind.
    --#}
    {%- call statement('snapshot_reset') -%}
      {{ stellar_dbt_public.snapshot_reset_from_start(
          target_relation,
          start_date,
          valid_from_col_name,
          valid_to_col_name,
          key_filter
      ) }}
    {%- endcall -%}

    {%- do log("Reset " ~ this.identifier ~ " to its state at " ~ start_date, info=true) -%}
  {% endif %}

  {#--
  -- Chunks run in ascending order and each one merges before the next begins, because a chunk
  -- reads the version the previous chunk left open. That also makes every chunk boundary a
  -- consistent snapshot: a failure part way through leaves the table correct up to the last
  -- chunk that finished, and the log line below records how far it got so a rerun can start
  -- from there.
  --#}
  {%- for chunk_range in chunk_ranges %}
    {%- set chunk_start_date = chunk_range[0] -%}
    {%- set chunk_end_date = chunk_range[1] -%}
    {%- set chunk_label = loop.index ~ "/" ~ chunk_ranges | length -%}

    {%- set diff_sql = stellar_dbt_public.calculate_snapshot_diff(
        config.get('source_name'),
        target_relation,
        this.project ~ '.' ~ this.schema ~ '.' ~ config.get('temp_source_table'),
        this.project ~ '.' ~ this.schema ~ '.' ~ config.get('temp_target_table'),
        chunk_start_date,
        chunk_end_date,
        config.get('updated_at_col_name'),
        valid_from_col_name,
        valid_to_col_name,
        source_unique_key,
        raw_partition_by,
        cluster_by,
        key_filter,
        ns.table_exists
    ) -%}

    {%- if not ns.table_exists %}
      {#-- Nothing to merge into yet: this chunk creates the table. --#}
      {%- call statement('main' if loop.last else 'create_chunk_' ~ loop.index, language=language) -%}
        {{ diff_sql }}
        {{ bq_create_table_as(partition_by, False, target_relation, compiled_code, language) }}
      {%- endcall -%}
      {%- set ns.table_exists = true -%}

    {%- else %}
      {%- call statement('build_chunk_' ~ loop.index, language=language) -%}
        {{ diff_sql }}
        {{ bq_create_table_as(partition_by, True, tmp_relation, compiled_code, language) }}
      {%- endcall -%}
      {%- set ns.tmp_relation_exists = true -%}

      {%- if ns.dest_columns is none -%}
        {%- set ns.dest_columns = process_schema_changes(on_schema_change, tmp_relation, target_relation) -%}
      {%- endif -%}

      {%- set build_sql = bq_generate_incremental_build_sql(
          strategy,
          tmp_relation,
          target_relation,
          compiled_code,
          unique_key,
          partition_by,
          partitions,
          ns.dest_columns,
          true,
          partition_by.copy_partitions,
          incremental_predicates
      ) -%}

      {%- call statement('main' if loop.last else 'merge_chunk_' ~ loop.index) -%}
        {{ build_sql }}
      {%- endcall -%}
    {%- endif %}

    {%- do log(
        "Chunk " ~ chunk_label ~ " done: " ~ this.identifier ~ " rebuilt through "
        ~ chunk_end_date ~ " (chunk covered " ~ chunk_start_date ~ " to " ~ chunk_end_date ~ ")",
        info=true
    ) -%}
  {%- endfor %}

  {{ run_hooks(post_hooks) }}

  {%- set target_relation = this.incorporate(type='table') -%}
  {% do persist_docs(target_relation, model) %}

  {%- if ns.tmp_relation_exists -%}
    {{ adapter.drop_relation(tmp_relation) }}
  {%- endif -%}

  {{ return({'relations': [target_relation]}) }}

{%- endif -%}

{%- endmaterialization %}
