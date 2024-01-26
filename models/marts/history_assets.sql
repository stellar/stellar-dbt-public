{{ config(
    tags = ["history_assets"]
    , materialized='incremental'
    , unique_key=["asset_id"]
    , cluster_by= ["asset_id"]
    )
}}

/* If the table is running incrementally, deduplicate assets and only add those that do not exist in the table */
{% if is_incremental() %}

    /* This query selects the deduplicated assets from the new load */
    with
        new_load as (
            select *
            from {{ ref('stg_history_assets') }}
        )

        /* selects the deduplicated table for comparision */
        , deduplicated_table as (
            select *
            from {{ this }}
        )

        /* excludes any assets from the load that already exist in the deduplicated table */
        , exclude_duplicates as (
            select
                new_load.asset_id
                , new_load.asset_code
                , new_load.asset_issuer
                , new_load.asset_type
            from new_load
            left join
                deduplicated_table on
            new_load.asset_id = deduplicated_table.asset_id
            where
                deduplicated_table.asset_id is null
        )

        /* Adds only the new assets from the load to the assets table */
        , add_assets as (
            select
                new_load.asset_id
                , exclude_duplicates.asset_type
                , exclude_duplicates.asset_code
                , exclude_duplicates.asset_issuer
                , new_load.batch_id
                , new_load.batch_run_date
                , new_load.batch_insert_ts
            from exclude_duplicates
            left join
                new_load on
            exclude_duplicates.asset_id = new_load.asset_id
        )

{% else %}
    /* If the table is being run in full-refresh mode, deduplicate all assets and generate table */

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
                , batch_insert_ts
            from prep_dedup
        )

{% endif %}

select *
from add_assets
