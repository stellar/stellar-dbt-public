with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'history_contract_events') }}
    )

    , history_contract_events as (
        select
            transaction_hash
            , transaction_id
            , successful
            , in_successful_contract_call
            , contract_id
            , type
            , type_string
            , topics
            , topics_decoded
            , data
            , data_decoded
            , contract_event_xdr
            , batch_id
            , batch_run_date
            , batch_insert_ts
            , closed_at
            , ledger_sequence
            , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
        from raw_table
    )

select *
from history_contract_events
