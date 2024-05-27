{{ config(
    tags = ["enriched_history_operations"]
    )
}}

with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'claimable_balances') }}
    )

    , claimable_balance as (
        select
            balance_id
            , claimants
            , asset_type
            , asset_code
            , asset_issuer
            , asset_amount
            , sponsor
            , flags
            , last_modified_ledger
            , ledger_entry_change
            , deleted
            , batch_id
            , batch_run_date
            , batch_insert_ts
            , closed_at
            , ledger_sequence
        from raw_table
        qualify
            row_number() over (
                partition by balance_id, ledger_entry_change
                order by closed_at desc
            ) = 1
    )

select *
from claimable_balance
