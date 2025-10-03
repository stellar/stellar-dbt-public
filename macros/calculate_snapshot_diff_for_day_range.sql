{% macro calculate_snapshot_diff_for_day_range(
    source_name,
    target_name,
    temp_source_table,
    temp_target_table,
    snapshot_start_date,
    snapshot_end_date,
    updated_at_col_name,
    valid_from_col_name,
    valid_to_col_name,
    source_unique_key,
    partition_by_key,
    cluster_by_key
) -%}

{#
-- Calculate snapshot diff for a given range of days
-- Snapshot row is calculated at day level i.e. all changes to an entity happened over a day are compressed to 1 record(latest state)
-- Snapshot row is inserted in target temp table.
#}

{%- set columns = adapter.get_columns_in_relation(ref(source_name)) -%}
{%- set dest_cols_csv = get_quoted_csv(columns | map(attribute="name")) -%}
{%- set date_range = stellar_dbt_public.generate_date_range(snapshot_start_date, snapshot_end_date) -%}
{%- set full_refresh_mode = (should_full_refresh()) -%}
{%- set existing_relation = load_relation(this) %}

{%- if source_unique_key is sequence and source_unique_key is not string -%}
    {%- set source_unique_key_cols = source_unique_key -%}
{%- else -%}
    {%- set source_unique_key_cols = [source_unique_key] -%}
{%- endif -%}

{#
-- 1. Create a target temp table when processing day 1 and reuse this table in while processing rest of the days.
-- 2. Create a source temp table for each day. It contains snapshot diff for a single day.
-- 3. Merge source temp table in target temp table. Target temp table will contain snapshot diff for multiple days.
-- 4. The downstream users read data from target temp table to get snapshot diff for multiple days.
#}

{%- for i in range(0, date_range | length - 1) %}
    {#-- Create temp target table when processing day 1 --#}
    {% if loop.index == 1 %}
        {%- if existing_relation is none or full_refresh_mode -%}
            {#-- Use source data if target does not exist yet or macro is run in full refresh mode  --#}
            {%- set source_data = stellar_dbt_public.calculate_snapshot_diff_for_day(
                    source_name,
                    none,
                    date_range[i],
                    date_range[i+1],
                    updated_at_col_name,
                    valid_from_col_name,
                    valid_to_col_name,
                    source_unique_key_cols
                ) -%}
            {{ stellar_dbt_public.create_temp_table_with_data(temp_target_table, source_data, partition_by_key, cluster_by_key) }}
        {%- else -%}
            {#-- Use active records from target data  --#}
            {%- set active_target_data = stellar_dbt_public.get_active_records_from_target_table(target_name, valid_to_col_name) -%}
            {{ stellar_dbt_public.create_temp_table_with_data(temp_target_table, active_target_data, partition_by_key, cluster_by_key) }}
        {% endif %}
    {% endif %}

    {#-- Create source temp table for given day  --#}
    {%- set source_data = stellar_dbt_public.calculate_snapshot_diff_for_day(
            source_name,
            temp_target_table,
            date_range[i],
            date_range[i+1],
            updated_at_col_name,
            valid_from_col_name,
            valid_to_col_name,
            source_unique_key_cols
        ) -%}

    {{ stellar_dbt_public.create_temp_table_with_data(temp_source_table, source_data, none, none) }}

    {#-- Merge source temp table into target temp table  --#}
    {{
        stellar_dbt_public.merge_source_into_target(
            temp_target_table,
            temp_source_table,
            source_unique_key_cols,
            valid_from_col_name,
            valid_to_col_name,
            dest_cols_csv
        )
    }}
{%- endfor %}
{%- endmacro %}
