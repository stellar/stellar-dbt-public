{# Returns meta_config without the keys that only belong in `meta`, so a model can pass
   `meta=meta_config, **without_meta_keys(meta_config)` to config() and keep custom keys
   (Datafold `datadiff`, the incremental_snapshot settings) out of the dbt config. #}
{% macro without_meta_keys(meta_config) %}
    {%- set meta_only_keys = [
        'datadiff',
        'source_name',
        'source_unique_key',
        'temp_source_table',
        'temp_target_table',
        'snapshot_default_start_date',
        'snapshot_start_date',
        'snapshot_end_date',
        'snapshot_keys',
        'snapshot_chunk_months',
        'updated_at_col_name',
        'valid_from_col_name',
        'valid_to_col_name',
    ] -%}
    {%- set model_config = {} -%}
    {%- for key, value in meta_config.items() if key not in meta_only_keys -%}
        {%- do model_config.update({key: value}) -%}
    {%- endfor -%}
    {{ return(model_config) }}
{% endmacro %}
