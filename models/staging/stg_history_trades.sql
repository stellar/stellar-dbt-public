{{ config(
    tags = ["enriched_history_operations"]
    )
}}

with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'history_trades')}}
    )

    , history_trades as (
        select
            history_operation_id
            , `order`
            , ledger_closed_at
            , selling_account_address
            , selling_asset_type
            , selling_asset_code
            , selling_asset_issuer
            , selling_asset_id
            , selling_amount
            , buying_account_address
            , buying_asset_type
            , buying_asset_code
            , buying_asset_issuer
            , buying_asset_id
            , buying_amount
            , price_n
            , price_d
            , selling_offer_id
            , buying_offer_id
            , selling_liquidity_pool_id
            , liquidity_pool_fee
            , trade_type
            , rounding_slippage
            , seller_is_exact
            , batch_id
            , batch_run_date
            , batch_insert_ts
        from raw_table
    )

select *
from history_trades
