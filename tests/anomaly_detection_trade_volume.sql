{{ config(severity="warn") }}

with
    base_trades as (
        select
            date(ledger_closed_at) as close_date
            , sum(buying_amount) as amount
        from {{ ref('stg_history_trades') }}
        where
            date(ledger_closed_at) >= date_sub(current_date(), interval 90 day)
            and date(ledger_closed_at) <= current_date()
        group by close_date
    )

    , counter_trades as (
        select
            date(ledger_closed_at) as close_date
            , sum(selling_amount) as amount
        from {{ ref('stg_history_trades') }}
        where
            date(ledger_closed_at) >= date_sub(current_date(), interval 90 day)
            and date(ledger_closed_at) < current_date()
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
    close_date = date_sub(current_date(), interval 1 day)
    and amount >= upper_bound
    or amount <= lower_bound
