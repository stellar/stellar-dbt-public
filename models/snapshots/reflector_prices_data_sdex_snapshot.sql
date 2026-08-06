-- depends_on: {{ ref('int_reflector_prices__sdex') }}
{%- set temp_source_table = this.table ~ '_source' -%}
{%- set temp_target_table = this.table ~ '_target' -%}

{% set meta_config = {
    "datadiff": {
        "unique_key": ["asset_contract_id", "valid_from"],
        "exclude_columns": [],
        "min_match_percent": 98,
        "filters": {"column": "valid_from"},
    },
    "materialized": "incremental_snapshot",
    "cluster_by": ["asset_contract_id"],
    "unique_key": ["asset_contract_id", "valid_from"],
    "source_unique_key": 'asset_contract_id',
    "source_name": 'int_reflector_prices__sdex',
    "temp_source_table": temp_source_table,
    "temp_target_table": temp_target_table,
    "snapshot_default_start_date": "2024-03-01",
    "snapshot_start_date": var("snapshot_start_date", none),
    "snapshot_end_date": var("snapshot_end_date", none),
    "full_refresh": true if var("snapshot_full_refresh", "false") == 'true' else none,
    "updated_at_col_name": 'day',
    "valid_from_col_name": 'valid_from',
    "valid_to_col_name": 'valid_to',
    "on_schema_change": 'append_new_columns',
    "tags": ["custom_snapshot_reflector_prices_data"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

SELECT * from {{ this.project ~ '.' ~ this.schema ~ '.' ~  temp_target_table }}
