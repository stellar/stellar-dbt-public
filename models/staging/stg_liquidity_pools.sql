{{ config(
    tags = ["current_state", "liquidity_pool_trade_volume", "liquidity_providers"]
    )
}}

with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'liquidity_pools')}}
    )

    , liquidity_pool as (
        select
            liquidity_pool_id
            , type
            , fee
            , trustline_count
            , pool_share_count
            , asset_a_type
            , asset_a_code
            , asset_a_issuer
            , asset_a_amount
            , asset_b_type
            , asset_b_code
            , asset_b_issuer
            , asset_b_amount
            , last_modified_ledger
            , ledger_entry_change
            , deleted
            , batch_id
            , batch_run_date
            , batch_insert_ts
        from raw_table
    )

select *
from liquidity_pool
