{% macro merge_source_into_target(
    target_table,
    source_table,
    source_unique_key_cols,
    valid_from_col_name,
    valid_to_col_name,
    dest_cols_csv
) -%}
    MERGE INTO {{ target_table }} AS DBT_INTERNAL_DEST
    USING {{ source_table }} AS DBT_INTERNAL_SOURCE
    ON ({%- for key in source_unique_key_cols -%}
        DBT_INTERNAL_SOURCE.{{ key }} = DBT_INTERNAL_DEST.{{ key }}
    {{ " AND " if not loop.last }}
    {%- endfor -%})
    AND DBT_INTERNAL_SOURCE.{{ valid_from_col_name }} = DBT_INTERNAL_DEST.{{ valid_from_col_name }}

    WHEN MATCHED THEN
        UPDATE SET {{ valid_to_col_name }} = DBT_INTERNAL_SOURCE.{{ valid_to_col_name }}

    WHEN NOT MATCHED THEN
        INSERT ({{ dest_cols_csv }}, {{ valid_from_col_name }}, {{ valid_to_col_name }})
        VALUES ({{ dest_cols_csv }}, {{ valid_from_col_name }}, {{ valid_to_col_name }});

{%- endmacro %}

{% macro get_active_records_from_target_table(
    target_name,
    valid_to_col_name
) -%}
    SELECT * FROM {{ target_name }} WHERE {{ valid_to_col_name }} IS NULL
{%- endmacro %}

{% macro create_temp_table_with_data(
    table_name,
    data,
    partition_by_key,
    cluster_by_key
) -%}
    CREATE OR REPLACE TABLE {{ table_name }}
    {% if partition_by_key %}
    {%- set partition_config = adapter.parse_partition_by(partition_by_key) -%}
    {{ partition_by(partition_config) }}
    {%- endif -%}

    {% if cluster_by_key %}
    {{ cluster_by(cluster_by_key) }}
    {{ " " }}
    {%- endif -%}

    OPTIONS(
        expiration_timestamp=TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 3 hour)
    )
    AS ({{data}});
{%- endmacro %}
