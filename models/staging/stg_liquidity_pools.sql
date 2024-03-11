{{ config(
    tags = ["enriched_history_operations", "liquidity_pools_value_history", "liquidity_pools_value"]
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
            , closed_at
            , ledger_sequence
        from raw_table
    )

select *
from liquidity_pool
