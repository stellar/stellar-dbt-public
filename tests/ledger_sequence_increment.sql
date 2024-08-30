{{ config(
    severity="warn"
    , tags=["singular_test"]
    )
}}

with
    ledger_sequence as (
        select
            id
            , batch_id
            , closed_at
            , max(sequence) as max_sequence
        from {{ source('crypto_stellar', 'history_ledgers') }}
        where TIMESTAMP(closed_at) > TIMESTAMP_SUB('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL 7 DAY )
        group by id, batch_id, closed_at
    )

    , lead_sequence as (
        select
            id
            , batch_id
            , closed_at
            , max_sequence
            , lead(max_sequence) over (
                order by closed_at desc
            ) as prev_sequence
        from ledger_sequence
    )

select *
from lead_sequence
where (
    prev_sequence >= max_sequence
    or max_sequence != prev_sequence + 1
)
