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
            , assets.contract_id as asset_contract_id
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
            , closed_at
            , ledger_sequence
            , batch_insert_ts
            , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
        from raw_table
        left join {{ ref('stg_assets') }} as assets
            on raw_table.asset_code = assets.asset_code
            and raw_table.asset_issuer = assets.asset_issuer
            and raw_table.asset_type = assets.asset_type
    )

select *
from trust_lines
