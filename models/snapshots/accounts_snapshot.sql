-- depends_on: {{ ref('stg_accounts') }}
{%- set temp_source_table = this.table ~ '_source' -%}
{%- set temp_target_table = this.table ~ '_target' -%}
{%- set snapshot_default_start_date = snapshot_begin('2015-09-30') -%}

{% set meta_config = {
    "datadiff": {
        "unique_key": ["account_id", "valid_from"],
        "exclude_columns": ["batch_id", "batch_run_date", "batch_insert_ts", "airflow_start_ts"],
        "min_match_percent": 98,
        "filters": {"column": "valid_from"},
    },
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
    "snapshot_default_start_date": snapshot_default_start_date,
    "snapshot_start_date": var("snapshot_start_date", none),
    "snapshot_end_date": var("snapshot_end_date", none),
    "full_refresh": true if var("snapshot_full_refresh", "false") == 'true' else none,
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
