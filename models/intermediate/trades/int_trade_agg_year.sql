{{ config(
    tags = ["trade_agg"]
    , cluster_by =["asset_a", "asset_b"]
    )
}}

/* TO-DO This query is costly and can be optimized by
creating an intermediate source that contains only 1 year of trading history.
That table could be used as a single source for each aggregate period
and we could keep a rolling 365 days of history by setting partition expiration.
*/

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
            ledger_closed_at < timestamp(date_add(date('{{ dbt_airflow_macros.ds() }}'), interval 1 day)
            )
            and ledger_closed_at >= timestamp_sub(timestamp(date('{{ dbt_airflow_macros.ds() }}')), interval 366 day)
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
            date('{{ dbt_airflow_macros.ds() }}') as day_agg
            , asset_a
            , asset_a_code
            , asset_a_issuer
            , asset_a_type
            , asset_b
            , asset_b_code
            , asset_b_issuer
            , asset_b_type
            , count(trade_key) as trade_count_yearly
            , sum(asset_a_amount) as asset_a_volume_yearly
            , sum(asset_b_amount) as asset_b_volume_yearly
            , sum(asset_b_amount) / sum(asset_a_amount) as avg_price_yearly
            , max(price_n / price_d) as high_price_yearly
            , min(price_n / price_d) as low_price_yearly
        from dedup_asset_pair
        where cast(ledger_closed_at as date) >= date_sub(date('{{ dbt_airflow_macros.ds() }}'), interval 365 day)
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
            ) as open_n_yearly
            , first_value(price_d) over (
                partition by
                    day_agg
                    , asset_a
                    , asset_b
                order by ledger_closed_at asc
            ) as open_d_yearly
            , last_value(price_n) over (
                partition by
                    day_agg
                    , asset_a
                    , asset_b
                order by ledger_closed_at asc
            ) as close_n_yearly
            , last_value(price_d) over (
                partition by
                    day_agg
                    , asset_a
                    , asset_b
                order by ledger_closed_at asc
            ) as close_d_yearly
            , row_number() over (
                partition by
                    day_agg
                    , asset_a
                    , asset_b
                order by ledger_closed_at desc
            ) as dedup_rows
        from dedup_asset_pair
        where cast(ledger_closed_at as date) >= date_sub(date('{{ dbt_airflow_macros.ds() }}'), interval 365 day)
    )

    /* joins all metrics related to the asset pair while deduplicating the window functions */
    , join_table_yearly as (
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
            , trade_day_agg_group.trade_count_yearly
            , trade_day_agg_group.asset_a_volume_yearly
            , trade_day_agg_group.asset_b_volume_yearly
            , trade_day_agg_group.avg_price_yearly
            , trade_day_agg_group.high_price_yearly
            , trade_day_agg_group.low_price_yearly
            , trade_day_agg_window.open_n_yearly
            , trade_day_agg_window.open_d_yearly
            , trade_day_agg_window.close_n_yearly
            , trade_day_agg_window.close_d_yearly
        from trade_day_agg_group
        left join
            trade_day_agg_window
            on
            trade_day_agg_group.day_agg = trade_day_agg_window.day_agg
            and trade_day_agg_group.asset_a = trade_day_agg_window.asset_a
            and trade_day_agg_group.asset_b = trade_day_agg_window.asset_b
        where trade_day_agg_window.dedup_rows = 1
    )


select *
from join_table_yearly
