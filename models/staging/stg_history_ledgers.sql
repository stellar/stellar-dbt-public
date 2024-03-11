{{ config(
    tags = ["enriched_history_operations", "liquidity_pools_value_history", "liquidity_pools_value"]
    )
}}

with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'history_ledgers')}}
    )

    , history_ledgers as (
        select
            sequence
            , ledger_hash
            , previous_ledger_hash
            , transaction_count
            , operation_count as ledger_operation_count
            , closed_at
            , id as ledger_id
            , total_coins
            , fee_pool
            , base_fee
            , base_reserve
            , max_tx_set_size
            , protocol_version
            , ledger_header
            , successful_transaction_count
            , failed_transaction_count
            , tx_set_operation_count
            , batch_id
            , batch_run_date
            , batch_insert_ts
        from raw_table
    )

select *
from history_ledgers
