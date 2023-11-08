{{ config(
    materialized='incremental',
    partition_by={
        "field": "day_agg"
        , "data_type": "date"
        , "granularity": "month"}
    , unique_key = ["day_agg", "asset_a", "asset_b"]
    , cluster_by =["asset_a", "asset_b"]
    )
}}

with
    trade_daily as (
        select *
        from {{ ref('int_trade_agg_day') }}
        {% if is_incremental() %}
            where day_agg = date('{{ dbt_airflow_macros.ds() }}')
        {% endif %}
    )

    , trade_weekly as (
        select *
        from {{ ref('int_trade_agg_week') }}
        {% if is_incremental() %}
            where day_agg = date('{{ dbt_airflow_macros.ds() }}')
        {% endif %}
    )

    , trade_monthly as (
        select *
        from {{ ref('int_trade_agg_month') }}
        {% if is_incremental() %}
            where day_agg = date('{{ dbt_airflow_macros.ds() }}')
        {% endif %}
    )

    , trade_yearly as (
        select *
        from {{ ref('int_trade_agg_year') }}
        {% if is_incremental() %}
            where day_agg = date('{{ dbt_airflow_macros.ds() }}')
        {% endif %}
    )

    , history_assets as (
        select *
        from {{ ref('history_assets') }}
    )

    , join_trades as (
        select
            join_table_daily.day_agg
            , join_table_daily.asset_a
            , join_table_daily.asset_b
            , join_table_daily.trade_count_daily
            , join_table_daily.asset_a_volume_daily
            , join_table_daily.asset_b_volume_daily
            , join_table_daily.avg_price_daily
            , join_table_daily.high_price_daily
            , join_table_daily.low_price_daily
            , join_table_daily.open_n_daily
            , join_table_daily.open_d_daily
            , join_table_daily.close_n_daily
            , join_table_daily.close_d_daily
            , join_table_weekly.trade_count_weekly
            , join_table_weekly.asset_a_volume_weekly
            , join_table_weekly.asset_b_volume_weekly
            , join_table_weekly.avg_price_weekly
            , join_table_weekly.high_price_weekly
            , join_table_weekly.low_price_weekly
            , join_table_weekly.open_n_weekly
            , join_table_weekly.open_d_weekly
            , join_table_weekly.close_n_weekly
            , join_table_weekly.close_d_weekly
            , join_table_monthly.trade_count_monthly
            , join_table_monthly.asset_a_volume_monthly
            , join_table_monthly.asset_b_volume_monthly
            , join_table_monthly.avg_price_monthly
            , join_table_monthly.high_price_monthly
            , join_table_monthly.low_price_monthly
            , join_table_monthly.open_n_monthly
            , join_table_monthly.open_d_monthly
            , join_table_monthly.close_n_monthly
            , join_table_monthly.close_d_monthly
            , join_table_yearly.trade_count_yearly
            , join_table_yearly.asset_a_volume_yearly
            , join_table_yearly.asset_b_volume_yearly
            , join_table_yearly.avg_price_yearly
            , join_table_yearly.high_price_yearly
            , join_table_yearly.low_price_yearly
            , join_table_yearly.open_n_yearly
            , join_table_yearly.open_d_yearly
            , join_table_yearly.close_n_yearly
            , join_table_yearly.close_d_yearly
        from trade_daily as join_table_daily
        left join
            trade_weekly as join_table_weekly
            on join_table_daily.day_agg = join_table_weekly.day_agg
            and join_table_daily.asset_a = join_table_weekly.asset_a
            and join_table_daily.asset_b = join_table_weekly.asset_b
        left join
            trade_monthly as join_table_monthly
            on join_table_daily.day_agg = join_table_monthly.day_agg
            and join_table_daily.asset_a = join_table_monthly.asset_a
            and join_table_daily.asset_b = join_table_monthly.asset_b
        left join
            trade_yearly as join_table_yearly
            on join_table_daily.day_agg = join_table_yearly.day_agg
            and join_table_daily.asset_a = join_table_yearly.asset_a
            and join_table_daily.asset_b = join_table_yearly.asset_b
    )

    , join_asset_a as (
        select
            join_trades.day_agg
            , join_trades.asset_a
            , join_trades.asset_b
            , join_trades.trade_count_daily
            , join_trades.asset_a_volume_daily
            , join_trades.asset_b_volume_daily
            , join_trades.avg_price_daily
            , join_trades.high_price_daily
            , join_trades.low_price_daily
            , join_trades.open_n_daily
            , join_trades.open_d_daily
            , join_trades.close_n_daily
            , join_trades.close_d_daily
            , join_trades.trade_count_weekly
            , join_trades.asset_a_volume_weekly
            , join_trades.asset_b_volume_weekly
            , join_trades.avg_price_weekly
            , join_trades.high_price_weekly
            , join_trades.low_price_weekly
            , join_trades.open_n_weekly
            , join_trades.open_d_weekly
            , join_trades.close_n_weekly
            , join_trades.close_d_weekly
            , join_trades.trade_count_monthly
            , join_trades.asset_a_volume_monthly
            , join_trades.asset_b_volume_monthly
            , join_trades.avg_price_monthly
            , join_trades.high_price_monthly
            , join_trades.low_price_monthly
            , join_trades.open_n_monthly
            , join_trades.open_d_monthly
            , join_trades.close_n_monthly
            , join_trades.close_d_monthly
            , join_trades.trade_count_yearly
            , join_trades.asset_a_volume_yearly
            , join_trades.asset_b_volume_yearly
            , join_trades.avg_price_yearly
            , join_trades.high_price_yearly
            , join_trades.low_price_yearly
            , join_trades.open_n_yearly
            , join_trades.open_d_yearly
            , join_trades.close_n_yearly
            , join_trades.close_d_yearly
            , ha.asset_code as asset_a_code
            , ha.asset_type as asset_a_type
            , ha.asset_issuer as asset_a_issuer
        from join_trades
        left join history_assets as ha
            on join_trades.asset_a = ha.asset_id
    )

    , join_asset_b as (
        select
            join_asset_a.day_agg
            , join_asset_a.asset_a_type
            , join_asset_a.asset_a_code
            , join_asset_a.asset_a_issuer
            , join_asset_a.asset_a
            , ha.asset_code as asset_b_code
            , ha.asset_type as asset_b_type
            , ha.asset_issuer as asset_b_issuer
            , join_asset_a.asset_b
            , join_asset_a.trade_count_daily
            , join_asset_a.asset_a_volume_daily
            , join_asset_a.asset_b_volume_daily
            , join_asset_a.avg_price_daily
            , join_asset_a.high_price_daily
            , join_asset_a.low_price_daily
            , join_asset_a.open_n_daily
            , join_asset_a.open_d_daily
            , join_asset_a.close_n_daily
            , join_asset_a.close_d_daily
            , join_asset_a.trade_count_weekly
            , join_asset_a.asset_a_volume_weekly
            , join_asset_a.asset_b_volume_weekly
            , join_asset_a.avg_price_weekly
            , join_asset_a.high_price_weekly
            , join_asset_a.low_price_weekly
            , join_asset_a.open_n_weekly
            , join_asset_a.open_d_weekly
            , join_asset_a.close_n_weekly
            , join_asset_a.close_d_weekly
            , join_asset_a.trade_count_monthly
            , join_asset_a.asset_a_volume_monthly
            , join_asset_a.asset_b_volume_monthly
            , join_asset_a.avg_price_monthly
            , join_asset_a.high_price_monthly
            , join_asset_a.low_price_monthly
            , join_asset_a.open_n_monthly
            , join_asset_a.open_d_monthly
            , join_asset_a.close_n_monthly
            , join_asset_a.close_d_monthly
            , join_asset_a.trade_count_yearly
            , join_asset_a.asset_a_volume_yearly
            , join_asset_a.asset_b_volume_yearly
            , join_asset_a.avg_price_yearly
            , join_asset_a.high_price_yearly
            , join_asset_a.low_price_yearly
            , join_asset_a.open_n_yearly
            , join_asset_a.open_d_yearly
            , join_asset_a.close_n_yearly
            , join_asset_a.close_d_yearly
        from join_asset_a
        left join history_assets as ha
            on join_asset_a.asset_b = ha.asset_id
    )

select *
from join_asset_b