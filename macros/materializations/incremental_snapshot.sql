{% materialization incremental_snapshot, adapter='bigquery', supported_languages=['sql'] -%}

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
-- start: which date wins depends on the mode, because the two modes disagree about what a
-- start date means.
--
-- An ordinary run rebuilds forward from the date it is given, so the snapshot_start_date var
-- decides it: a daily run passes yesterday, a partial rebuild passes the point to rebuild from.
-- There is no fallback. The model's default is a genesis date, so using it here would turn a
-- missing var into a silent rebuild of the whole table -- years of history deleted and
-- recomputed where one day was intended, reported as success. A run with no start date is a
-- mistake, so it fails.
--
-- A full refresh replaces the table outright, so its start date decides how much history the
-- snapshot ends up having at all. The model's snapshot_default_start_date therefore wins over
-- whatever the caller passed: a full refresh triggered from a pipeline that routinely sets
-- snapshot_start_date to yesterday would otherwise replace the table with a single day and
-- discard everything before it. Falling back to the requested date keeps a full refresh
-- possible for a model that has no default recorded yet.
--
-- To rebuild only part of the history on purpose, use an ordinary run with an early start
-- rather than a full refresh -- the reset deletes from that date forward regardless.
--
-- end: snapshot_end_date, defaulting to today. It bounds what is rebuilt, not what is deleted:
-- step 1 deletes every version from start_date onward with no upper bound, while the chunks
-- rebuild only as far as the end date. So an end date in the past truncates the snapshot at that
-- date rather than repairing a window -- hole repair is not supported.
--#}
{%- set requested_start_date = config.get('snapshot_start_date') -%}
{%- set default_start_date = config.get('snapshot_default_start_date', none) -%}

{%- if full_refresh_mode -%}
  {%- set start_date = default_start_date or requested_start_date -%}
  {%- if default_start_date and requested_start_date and default_start_date != requested_start_date -%}
    {%- do log(
        "Full refresh of " ~ this.identifier ~ ": rebuilding from its snapshot_default_start_date "
        ~ default_start_date ~ ", not the requested " ~ requested_start_date
        ~ ", so the replaced table keeps its whole history",
        info=true
    ) -%}
  {%- endif -%}
{%- else -%}
  {%- set start_date = requested_start_date -%}
{%- endif -%}

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

{%- set end_date = config.get('snapshot_end_date') or run_started_at.strftime('%Y-%m-%d') -%}

{#--
-- Both dates are day-granular here: the chunk boundaries and the reset's predicates are days,
-- so a caller may pass either a date or a full timestamp ("2026-06-16 13:00:00+00:00") and the
-- time is dropped. Truncating here rather than at the caller keeps every caller -- Airflow,
-- a --vars run, a model config -- passing whatever timestamp it already has.
--#}
{%- set start_date = (start_date | string | replace("'", "") | trim)[:10] -%}
{%- set end_date = (end_date | string | replace("'", "") | trim)[:10] -%}

{%- if start_date >= end_date -%}
  {%- do exceptions.raise_compiler_error(
      "Start date " ~ start_date ~ " for " ~ this.identifier ~ " is not before the end of the "
      ~ "rebuild window (" ~ end_date ~ ")."
  ) -%}
{%- endif -%}

{%- set chunk_months = config.get('snapshot_chunk_months', var('snapshot_chunk_months', 3)) | int -%}
{%- set chunk_ranges = stellar_dbt_public.snapshot_chunk_ranges(start_date, end_date, chunk_months) -%}

{#--
-- Threaded into every statement that reads or writes the target -- a statement built without it
-- deletes entities nobody asked about. calculate_snapshot_diff re-derives an aliased variant for
-- its boundary read, from the same source_unique_key_cols, so the two cannot disagree.
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

{%- endmaterialization %}
