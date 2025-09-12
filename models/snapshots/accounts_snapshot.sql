-- depends_on: {{ ref('stg_accounts') }}
{%- set temp_source_table = this.table ~ '_source' -%}
{%- set temp_target_table = this.table ~ '_target' -%}

{% set meta_config = {
    "materialized": "incremental_snapshot",
    "partition_by": {
         "field": "valid_to"
        , "data_type": "timestamp"
        , "granularity": "month"
    },
    "cluster_by": ["account_id"],
    "unique_key": ["account_id", "valid_from"],
    "source_unique_key": 'account_id',
    "source_name": 'stg_accounts',
    "temp_source_table": temp_source_table,
    "temp_target_table": temp_target_table,
    "snapshot_start_date": var("snapshot_start_date"),
    "snapshot_end_date": var("snapshot_end_date"),
    "full_refresh": var("snapshot_full_refresh") == 'true',
    "updated_at_col_name": 'closed_at',
    "valid_from_col_name": 'valid_from',
    "valid_to_col_name": 'valid_to',
    "on_schema_change": 'append_new_columns',
    "tags": ["custom_snapshot_accounts"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

SELECT * from {{ this.project ~ '.' ~ this.schema ~ '.' ~  temp_target_table }}
