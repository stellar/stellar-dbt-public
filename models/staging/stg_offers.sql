with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'offers') }}
    )

    , offers as (
        select
            seller_id
            , offer_id
            , selling_asset_type
            , selling_asset_code
            , selling_asset_issuer
            , selling_asset_id
            , selling_assets.contract_id as selling_asset_contract_id
            , buying_asset_type
            , buying_asset_code
            , buying_asset_issuer
            , buying_asset_id
            , buying_assets.contract_id as buying_asset_contract_id
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
            , closed_at
            , ledger_sequence
            , batch_insert_ts
            , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
        from raw_table
        left join {{ ref('stg_assets') }} as selling_assets
            on raw_table.selling_asset_code = selling_assets.asset_code
            and raw_table.selling_asset_issuer = selling_assets.asset_issuer
            and raw_table.selling_asset_type = selling_assets.asset_type
        left join {{ ref('stg_assets') }} as buying_assets
            on raw_table.buying_asset_code = buying_assets.asset_code
            and raw_table.buying_asset_issuer = buying_assets.asset_issuer
            and raw_table.buying_asset_type = buying_assets.asset_type
    )

select *
from offers
