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
