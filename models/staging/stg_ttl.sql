{{ config(
    tags = ["enriched_history_operations"]
    )
}}

with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'ttl') }}
    )

    , ttl as (
        select
            key_hash
            , live_until_ledger_seq
            , last_modified_ledger
            , ledger_entry_change
            , deleted
            , ledger_sequence
            , closed_at
            , batch_id
            , batch_run_date
        from raw_table
    )

select *
from ttl
