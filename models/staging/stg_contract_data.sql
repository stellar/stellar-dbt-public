with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'contract_data') }}
    )

    , contract_data as (
        select
            contract_id
            , contract_key_type
            , contract_durability
            , asset_code
            , asset_issuer
            , asset_type
            , balance_holder
            , balance
            , last_modified_ledger
            , ledger_entry_change
            , ledger_sequence
            , ledger_key_hash
            , closed_at
            , deleted
            , batch_id
            , batch_run_date
            , batch_insert_ts
        from raw_table
    )

select *
from raw_table