with raw_table as (
    select *
    {% if target.name == 'prod' %}
    from {{ source('crypto_stellar_internal_2', 'history_transactions') }}
    {% else %}
    from {{ source('dbt_sample', 'sample_history_transactions') }}
    {% endif %}
)

, history_transactions as (
    select
        id as transaction_id
        , transaction_hash
        , ledger_sequence
        , application_order as txn_application_order
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
        , batch_id
        , batch_run_date
        , batch_insert_ts
    from raw_table
)

select *
from history_transactions