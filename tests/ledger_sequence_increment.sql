{{ config(
    severity="warn"
    , tags=["singular_test"]
    , enabled = ('{{ var("is_singular_airflow_task") }}' == "true")
    )
}}

with
    ledger_sequence as (
        select
            ledger_id
            , batch_id
            , closed_at
            , max(sequence) as max_sequence
        from {{ ref('stg_history_ledgers') }}
        where closed_at > TIMESTAMP_SUB('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL 7 DAY )
        group by ledger_id, batch_id, closed_at
    )

    , lead_sequence as (
        select
            ledger_id
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
