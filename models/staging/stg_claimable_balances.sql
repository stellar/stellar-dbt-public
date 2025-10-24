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
            , asset_id
            , asset_amount
            , sponsor
            , flags
            , last_modified_ledger
            , ledger_entry_change
            , deleted
            , batch_id
            , batch_run_date
            , closed_at
            , ledger_sequence
            , batch_insert_ts
            , assets.contract_id as asset_contract_id
            , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
        from raw_table
        left join {{ ref('stg_assets') }} as assets
            on raw_table.asset_code = assets.asset_code
            and raw_table.asset_issuer = assets.asset_issuer
            and raw_table.asset_type = assets.asset_type
    )

select *
from claimable_balance
