{{ config(
    cluster_by =["asset_a", "asset_b"]
    )
}}

-- This model is materialized as a table and fully rebuilt on every run. It
-- reads all trade history (up to batch_end_date) and, for every day a pair
-- traded, emits the trailing 30-day (D-30 .. D inclusive) rolling metrics as of
-- that day. Grain: (day_agg, asset pair). The rolling windows are computed with
-- window functions over a per-day base so complete history is produced in a
-- single pass rather than one reference day per run.

/* select columns from the history_trades table and generates unique trade key*/
with
    base_trades as (
        select
            ledger_closed_at
            , cast(ledger_closed_at as date) as day_agg
            , selling_asset_id
            , selling_asset_code
            , selling_asset_issuer
            , selling_asset_type
            , buying_asset_id
            , buying_asset_code
            , buying_asset_issuer
            , buying_asset_type
            , concat(history_operation_id, `order`) as trade_key
            , price_n
            , price_d
            , selling_amount
            , buying_amount
        from {{ ref('stg_history_trades') }}
        where
            ledger_closed_at < timestamp(date('{{ var("batch_end_date") }}'))
    )

    /* duplicates trades in order to obtain all trades between an asset pair, regardless
    of selling or buying */
    , asset_pair_prep as (
        select
            day_agg
            , ledger_closed_at
            , selling_asset_id as asset_a
            , selling_asset_code as asset_a_code
            , selling_asset_issuer as asset_a_issuer
            , selling_asset_type as asset_a_type
            , buying_asset_id as asset_b
            , buying_asset_code as asset_b_code
            , buying_asset_issuer as asset_b_issuer
            , buying_asset_type as asset_b_type
            , trade_key
            , price_n
            , price_d
            , selling_amount as asset_a_amount
            , buying_amount as asset_b_amount
        from base_trades
        union all
        select
            day_agg
            , ledger_closed_at
            , selling_asset_id as asset_b
            , selling_asset_code as asset_b_code
            , selling_asset_issuer as asset_b_issuer
            , selling_asset_type as asset_b_type
            , buying_asset_id as asset_a
            , buying_asset_code as asset_a_code
            , buying_asset_issuer as asset_a_issuer
            , buying_asset_type as asset_a_type
            , trade_key
            , price_n
            , price_d
            , selling_amount as asset_b_amount
            , buying_amount as asset_a_amount
        from base_trades
    )

    /* order the trades so that they can be deduplicated*/
    , order_trades as (
        select
            day_agg
            , ledger_closed_at
            , asset_a
            , asset_a_code
            , asset_a_issuer
            , asset_a_type
            , asset_b
            , asset_b_code
            , asset_b_issuer
            , asset_b_type
            , trade_key
            , price_n
            , price_d
            , asset_a_amount
            , asset_b_amount
            , row_number() over (
                partition by trade_key
                order by asset_a asc
            ) as pair_dedup
        from asset_pair_prep
    )

    /* deduplicates based on unique trade key in order to obtain single results for each
    asset pair */
    , dedup_asset_pair as (
        select
            day_agg
            , ledger_closed_at
            , asset_a
            , asset_a_code
            , asset_a_issuer
            , asset_a_type
            , asset_b
            , asset_b_code
            , asset_b_issuer
            , asset_b_type
            , trade_key
            , price_n
            , price_d
            , asset_a_amount
            , asset_b_amount
        from order_trades
        where pair_dedup = 1
    )

    /* carry each day's open/close price (first/last trade of the day per pair)
    so the rolling open/close can be derived from the per-day base */
    , daily_trades as (
        select
            day_agg
            , asset_a
            , asset_a_code
            , asset_a_issuer
            , asset_a_type
            , asset_b
            , asset_b_code
            , asset_b_issuer
            , asset_b_type
            , trade_key
            , price_n
            , price_d
            , asset_a_amount
            , asset_b_amount
            , first_value(price_n) over pair_day_asc as day_open_n
            , first_value(price_d) over pair_day_asc as day_open_d
            , first_value(price_n) over pair_day_desc as day_close_n
            , first_value(price_d) over pair_day_desc as day_close_d
        from dedup_asset_pair
        window
            pair_day_asc as (
                partition by day_agg, asset_a, asset_b
                order by ledger_closed_at asc
            )
            , pair_day_desc as (
                partition by day_agg, asset_a, asset_b
                order by ledger_closed_at desc
            )
    )

    /* one row per (day, asset pair) with that day's aggregate metrics */
    , daily_metrics as (
        select
            day_agg
            , asset_a
            , asset_a_code
            , asset_a_issuer
            , asset_a_type
            , asset_b
            , asset_b_code
            , asset_b_issuer
            , asset_b_type
            , count(trade_key) as daily_trade_count
            , sum(asset_a_amount) as daily_asset_a_volume
            , sum(asset_b_amount) as daily_asset_b_volume
            , max(price_n / price_d) as daily_high_price
            , min(price_n / price_d) as daily_low_price
            , any_value(day_open_n) as day_open_n
            , any_value(day_open_d) as day_open_d
            , any_value(day_close_n) as day_close_n
            , any_value(day_close_d) as day_close_d
        from daily_trades
        group by
            day_agg
            , asset_a
            , asset_a_code
            , asset_a_issuer
            , asset_a_type
            , asset_b
            , asset_b_code
            , asset_b_issuer
            , asset_b_type
    )

    /* trailing 30-day rolling window (D-30 .. D inclusive) per asset pair */
    , rolling_monthly as (
        select
            day_agg
            , asset_a
            , asset_a_code
            , asset_a_issuer
            , asset_a_type
            , asset_b
            , asset_b_code
            , asset_b_issuer
            , asset_b_type
            , sum(daily_trade_count) over w as trade_count_monthly
            , sum(daily_asset_a_volume) over w as asset_a_volume_monthly
            , sum(daily_asset_b_volume) over w as asset_b_volume_monthly
            , sum(daily_asset_b_volume) over w
                / sum(daily_asset_a_volume) over w as avg_price_monthly
            , max(daily_high_price) over w as high_price_monthly
            , min(daily_low_price) over w as low_price_monthly
            , first_value(day_open_n) over w as open_n_monthly
            , first_value(day_open_d) over w as open_d_monthly
            , day_close_n as close_n_monthly
            , day_close_d as close_d_monthly
        from daily_metrics
        window
            w as (
                partition by asset_a, asset_b
                order by unix_date(day_agg)
                range between 30 preceding and current row
            )
    )


select
    *
    , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
from rolling_monthly
