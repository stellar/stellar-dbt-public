-- depends_on: {{ ref('int_reflector_prices__fex') }}
{%- set temp_source_table = this.table ~ '_source' -%}
{%- set temp_target_table = this.table ~ '_target' -%}

{% set meta_config = {
    "materialized": "incremental_snapshot",
    "partition_by": {
         "field": "valid_to"
        , "data_type": "timestamp"
        , "granularity": "month"
    },
    "cluster_by": ["asset_code"],
    "unique_key": ["asset_code", "valid_from"],
    "source_unique_key": 'asset_code',
    "source_name": 'int_reflector_prices__fex',
    "temp_source_table": temp_source_table,
    "temp_target_table": temp_target_table,
    "snapshot_start_date": var("snapshot_start_date"),
    "snapshot_end_date": var("snapshot_end_date"),
    "full_refresh": var("snapshot_full_refresh") == 'true',
    "updated_at_col_name": 'updated_at',
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
