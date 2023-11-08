/* This query prepares the assets of each load for deduplication,
in order to guarantee a new asset won't be loaded twice */
with
    new_load as (
        select
            *
            , row_number() over (
                partition by asset_id order by batch_run_date asc
            ) as dedup_oldest_asset
        from {{ source('crypto_stellar', 'history_assets_staging')}}
    )

    /* Deduplicates the new batch assets, guaranteeing they are unique within the batch */
    , new_load_dedup as (
        select *
        from new_load
        where dedup_oldest_asset = 1
    )

select *
from new_load_dedup
