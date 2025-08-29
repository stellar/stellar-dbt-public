with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'restored_key') }}
    )

    , restored_key as (
        select
            ledger_key_hash
            , ledger_entry_type
            , last_modified_ledger
            , closed_at
            , ledger_sequence
            , ledger_entry_change
            , batch_id
            , batch_run_date
            , batch_insert_ts
            , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
        from raw_table
    )

select *
from restored_key
