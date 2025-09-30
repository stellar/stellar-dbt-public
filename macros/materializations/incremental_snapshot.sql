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
  {%- set presql = stellar_dbt_public.calculate_snapshot_diff_for_day_range(
      config.get('source_name'),
      this,
      this.project ~ '.' ~ this.schema ~ '.' ~ config.get('temp_source_table'),
      this.project ~ '.' ~ this.schema ~ '.' ~ config.get('temp_target_table'),
      config.get('snapshot_start_date'),
      config.get('snapshot_end_date'),
      config.get('updated_at_col_name'),
      config.get('valid_from_col_name'),
      config.get('valid_to_col_name'),
      config.get('source_unique_key'),
      config.get('partition_by', none),
      config.get('cluster_by', none)
  ) -%}

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

  {{ run_hooks(pre_hooks) }}

  {% if existing_relation is none or full_refresh_mode %}
    {#-- If the partition/cluster config has changed, then we must drop and recreate --#}
    {% if existing_relation and not adapter.is_replaceable(existing_relation, partition_by, cluster_by) %}
      {% do log("Hard refreshing " ~ existing_relation ~ " because it is not replaceable") %}
      {{ adapter.drop_relation(existing_relation) }}
    {% endif %}

    {%- call statement('main', language=language) -%}
      {{ presql }}
      {{ bq_create_table_as(partition_by, False, target_relation, compiled_code, language) }}
    {%- endcall -%}

  {% else %}

    {%- call statement('create_tmp_relation', language=language) -%}
      {{ presql }}
      {{ bq_create_table_as(partition_by, True, tmp_relation, compiled_code, language) }}
    {%- endcall -%}

    {%- set tmp_relation_exists = true -%}
    {%- set dest_columns = process_schema_changes(on_schema_change, tmp_relation, existing_relation) -%}

    {% set build_sql = bq_generate_incremental_build_sql(
        strategy,
        tmp_relation,
        target_relation,
        compiled_code,
        unique_key,
        partition_by,
        partitions,
        dest_columns,
        tmp_relation_exists,
        partition_by.copy_partitions,
        incremental_predicates
    ) %}

    {%- call statement('main') -%}
      {{ build_sql }}
    {% endcall %}

  {% endif %}

  {{ run_hooks(post_hooks) }}

  {%- set target_relation = this.incorporate(type='table') -%}
  {% do persist_docs(target_relation, model) %}

  {%- if tmp_relation_exists -%}
    {{ adapter.drop_relation(tmp_relation) }}
  {%- endif -%}

  {{ return({'relations': [target_relation]}) }}

{%- endif -%}

{%- endmaterialization %}
