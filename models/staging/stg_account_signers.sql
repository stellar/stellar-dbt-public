{{ config(
    tags = ["enriched_history_operations"]
    )
}}

with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'account_signers')}}
    )

    , account_signers as (
        select
            account_id
            , signer
            , weight
            , sponsor
            , last_modified_ledger
            , ledger_entry_change
            , deleted
            , batch_id
            , batch_run_date
            , batch_insert_ts
            , closed_at
            , ledger_sequence
        from raw_table
    )

select *
from account_signers
