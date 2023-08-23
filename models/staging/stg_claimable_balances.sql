with
    raw_table as (
        select *
        from {{ source('crypto-stellar', 'claimable_balances')}}
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
        from raw_table
    )

select *
from claimable_balance
