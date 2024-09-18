{{ config(
    severity="warn"
    , tags=["singular_test"]
    , enabled = (target.name == "prod" and {{ var("is_singular_airflow_task") }} == "true")
    )
}}

with
    trade_counts as (
        select
            date(ledger_closed_at) as close_date
            , count(*) as trade_count
        from {{ ref('stg_history_trades') }}
        where
            ledger_closed_at >= TIMESTAMP_SUB('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL 90 DAY )
            and ledger_closed_at <= timestamp_trunc('{{dbt_airflow_macros.ts(timezone=none) }}', day)
        group by close_date
    )

    , bounds as (
        select
            (avg(trade_count) - (3 * stddev(trade_count))) as lower_bound
            , (avg(trade_count) + (3 * stddev(trade_count))) as upper_bound
        from trade_counts
    )

select
    close_date
    , trade_count
from trade_counts, bounds
where
    TIMESTAMP(close_date) = TIMESTAMP_SUB('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL 1 DAY )
    and (trade_count >= upper_bound
    or trade_count <= lower_bound)
