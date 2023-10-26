with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'trust_lines')}}
    )

    , trust_lines as (
        select
            ledger_key
            , account_id
            , asset_type
            , asset_issuer
            , asset_code
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
        from raw_table
    )

select *
from trust_lines
