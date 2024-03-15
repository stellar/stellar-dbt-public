{{ config(severity="warn") }}

with
    trade_counts as (
        select
            date(ledger_closed_at) as close_date
            , count(*) as trade_count
        from {{ ref('stg_history_trades') }}
        where
            date(ledger_closed_at) >= date_sub(current_date(), interval 90 day)
            and date(ledger_closed_at) < current_date()
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
    close_date = date_sub(current_date(), interval 1 day)
    and trade_count >= upper_bound
    or trade_count <= lower_bound
