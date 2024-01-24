{{ config(
    tags = ["current_state"]
    )
}}

with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'offers')}}
    )

    , offers as (
        select
            seller_id
            , offer_id
            , selling_asset_type
            , selling_asset_code
            , selling_asset_issuer
            , buying_asset_type
            , buying_asset_code
            , buying_asset_issuer
            , amount
            , pricen
            , priced
            , price
            , flags
            , sponsor
            , last_modified_ledger
            , ledger_entry_change
            , deleted
            , batch_id
            , batch_run_date
            , batch_insert_ts
        from raw_table
    )

select *
from offers
