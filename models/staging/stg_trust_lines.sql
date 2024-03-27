{{ config(
    tags = ["enriched_history_operations"]
    )
}}

with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'trust_lines') }}
    )

    , trust_lines as (
        select
            ledger_key
            , account_id
            , asset_type
            , asset_issuer
            , asset_code
            , asset_id
            , liquidity_pool_id
            , balance
            , trust_line_limit
            , buying_liabilities
            , selling_liabilities
            , flags
            , last_modified_ledger
            , ledger_entry_change
            , deleted
            , sponsor
            , batch_id
            , batch_run_date
            , batch_insert_ts
            , closed_at
            , ledger_sequence
        from raw_table
    )

select *
from trust_lines
