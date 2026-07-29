{% set meta_config = {
    "datadiff": {
        "unique_key": ["asset_id"],
        "exclude_columns": ["batch_id", "batch_run_date", "batch_insert_ts", "airflow_start_ts"],
        "min_match_percent": 98,
    },
    "materialized": "table",
    "cluster_by": ["asset_id"],
    "tags": ["history_assets"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

/* Deduplicate all assets and generate the table */
with
    prep_dedup as (
        select
            *
            , row_number() over (
                partition by asset_id
                order by batch_run_date asc
            ) as dedup_grouping
        from {{ ref('stg_history_assets') }}
    )

    , add_assets as (
        select
            asset_id
            , asset_type
            , asset_code
            , asset_issuer
            , batch_id
            , batch_run_date
        from prep_dedup
    )

select
    *
    , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
from add_assets
