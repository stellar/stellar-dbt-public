{{ config(
    tags = ["enriched_history_operations"]
    )
}}

with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'contract_code') }}
    )

    , contract_code as (
        select
            contract_code_hash
            , contract_code_ext_v
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
from contract_code