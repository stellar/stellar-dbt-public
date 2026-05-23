with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'trust_lines') }}
    )

    , trust_lines as (
        select
            ledger_key
            , account_id
            , raw_table.asset_type
            , raw_table.asset_issuer
            , raw_table.asset_code
            , asset_id
            , liquidity_pool_id
            , liquidity_pool_id_strkey
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
            , closed_at
            , ledger_sequence
            , batch_insert_ts
            , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
        from raw_table
    )

select *
from trust_lines
