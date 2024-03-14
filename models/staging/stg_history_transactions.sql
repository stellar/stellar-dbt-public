{{ config(
    tags = ["enriched_history_operations"]
    )
}}

with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'history_transactions') }}
    )

    , history_transactions as (
        select
            id as transaction_id
            , transaction_hash
            , ledger_sequence
            , account as txn_account
            , account_sequence
            , max_fee
            , operation_count as txn_operation_count
            , created_at as txn_created_at
            , memo_type
            , memo
            , time_bounds
            , successful
            , fee_charged
            , inner_transaction_hash
            , fee_account
            , new_max_fee
            , account_muxed
            , fee_account_muxed
            , ledger_bounds as ledger_bounds
            , min_account_sequence as min_account_sequence
            , min_account_sequence_age as min_account_sequence_age
            , min_account_sequence_ledger_gap as min_account_sequence_ledger_gap
            , extra_signers
            , tx_envelope
            , tx_result
            , tx_meta
            , tx_fee_meta
            , resource_fee
            , soroban_resources_instructions
            , soroban_resources_read_bytes
            , soroban_resources_write_bytes
            , closed_at
            , batch_id
            , batch_run_date
            , batch_insert_ts
        from raw_table
    )

select *
from history_transactions
