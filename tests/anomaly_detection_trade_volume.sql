{{ config(
    severity="warn"
    , tags=["singular_test"]
    )
}}

with
    base_trades as (
        select
            date(ledger_closed_at) as close_date
            , sum(buying_amount) as amount
        from {{ ref('stg_history_trades') }}
        where
            TIMESTAMP({{ ledger_closed_at }}) >= TIMESTAMP_SUB('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL 90 DAY )
            and TIMESTAMP({{ ledger_closed_at }}) < '{{ dbt_airflow_macros.ts(timezone=none) }}'
        group by close_date
    )

    , counter_trades as (
        select
            date(ledger_closed_at) as close_date
            , sum(selling_amount) as amount
        from {{ ref('stg_history_trades') }}
        where
            TIMESTAMP({{ ledger_closed_at }}) >= TIMESTAMP_SUB('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL 90 DAY )
            and TIMESTAMP({{ ledger_closed_at }}) < '{{ dbt_airflow_macros.ts(timezone=none) }}'
        group by close_date
    )

    , data_table as (
        select
            close_date
            , sum(amount) as amount
        from (
            select *
            from base_trades
            union all
            select *
            from counter_trades
        )
        group by close_date
    )

    , bounds as (
        select
            (avg(amount) - (3 * stddev(amount))) as lower_bound
            , (avg(amount) + (3 * stddev(amount))) as upper_bound
        from data_table
    )

select
    close_date
    , amount
from data_table, bounds
where
    TIMESTAMP({{ close_date }}) = TIMESTAMP_SUB('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL 1 DAY )
    and amount >= upper_bound
    or amount <= lower_bound
