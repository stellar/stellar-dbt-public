{{ config()
}}

with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'account_signers') }}
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
            , closed_at
            , ledger_sequence
            , batch_insert_ts
            , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
        from raw_table
    )

select *
from account_signers
