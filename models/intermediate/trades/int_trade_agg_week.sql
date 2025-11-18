{{ config(
    cluster_by =["asset_a", "asset_b"]
    )
}}

-- TODO: The int_trade_agg tables need to be refactored to handle incremental
-- builds correctly. Currently it only builds a single day even if the model
-- is full-refreshed.

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
            -- TODO: Add incremental logic here
            ledger_closed_at < timestamp(date('{{ var("batch_end_date") }}'))
            and ledger_closed_at >= timestamp(date_sub(date('{{ var("batch_start_date") }}'), interval 8 day))
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

    /* obtain aggregate function metrics for the asset pair */
    , trade_day_agg_group as (
        select
            date('{{ var("batch_start_date") }}') as day_agg
            , asset_a
            , asset_a_code
            , asset_a_issuer
            , asset_a_type
            , asset_b
            , asset_b_code
            , asset_b_issuer
            , asset_b_type
            , count(trade_key) as trade_count_weekly
            , sum(asset_a_amount) as asset_a_volume_weekly
            , sum(asset_b_amount) as asset_b_volume_weekly
            , sum(asset_b_amount) / sum(asset_a_amount) as avg_price_weekly
            , max(price_n / price_d) as high_price_weekly
            , min(price_n / price_d) as low_price_weekly
        from dedup_asset_pair
        where ledger_closed_at >= timestamp(date_sub(date('{{ var("batch_start_date") }}'), interval 7 day))
        group by
            asset_a
            , asset_a_code
            , asset_a_issuer
            , asset_a_type
            , asset_b
            , asset_b_code
            , asset_b_issuer
            , asset_b_type
    )

    /* obtain window function metrics for the asset pair */
    , trade_day_agg_window as (
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
            , ledger_closed_at
            , first_value(price_n) over (
                partition by
                    day_agg
                    , asset_a
                    , asset_b
                order by ledger_closed_at asc
            ) as open_n_weekly
            , first_value(price_d) over (
                partition by
                    day_agg
                    , asset_a
                    , asset_b
                order by ledger_closed_at asc
            ) as open_d_weekly
            , last_value(price_n) over (
                partition by
                    day_agg
                    , asset_a
                    , asset_b
                order by ledger_closed_at asc
            ) as close_n_weekly
            , last_value(price_d) over (
                partition by
                    day_agg
                    , asset_a
                    , asset_b
                order by ledger_closed_at asc
            ) as close_d_weekly
            , row_number() over (
                partition by
                    day_agg
                    , asset_a
                    , asset_b
                order by ledger_closed_at desc
            ) as dedup_rows
        from dedup_asset_pair
        where ledger_closed_at >= timestamp(date_sub(date('{{ var("batch_start_date") }}'), interval 7 day))
    )

    /* joins all metrics related to the asset pair while deduplicating the window functions */
    , join_table_weekly as (
        select
            trade_day_agg_group.day_agg
            , trade_day_agg_group.asset_a
            , trade_day_agg_group.asset_a_code
            , trade_day_agg_group.asset_a_issuer
            , trade_day_agg_group.asset_a_type
            , trade_day_agg_group.asset_b
            , trade_day_agg_group.asset_b_code
            , trade_day_agg_group.asset_b_issuer
            , trade_day_agg_group.asset_b_type
            , trade_day_agg_group.trade_count_weekly
            , trade_day_agg_group.asset_a_volume_weekly
            , trade_day_agg_group.asset_b_volume_weekly
            , trade_day_agg_group.avg_price_weekly
            , trade_day_agg_group.high_price_weekly
            , trade_day_agg_group.low_price_weekly
            , trade_day_agg_window.open_n_weekly
            , trade_day_agg_window.open_d_weekly
            , trade_day_agg_window.close_n_weekly
            , trade_day_agg_window.close_d_weekly
        from trade_day_agg_group
        left join
            trade_day_agg_window
            on
            trade_day_agg_group.day_agg = trade_day_agg_window.day_agg
            and trade_day_agg_group.asset_a = trade_day_agg_window.asset_a
            and trade_day_agg_group.asset_b = trade_day_agg_window.asset_b
        where trade_day_agg_window.dedup_rows = 1
    )


select
    *
    , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
from join_table_weekly
