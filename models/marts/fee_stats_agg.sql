{{ config(
    tags=["fee_stats"],
    materialized='incremental',
    unique_key=["day_agg"],
    partition_by={
        "field": "day_agg"
        , "data_type": "date"
        , "granularity": "month"}
    )
}}

{%
    set percentiles = [
        10
        , 20
        , 30
        , 40
        , 50
        , 60
        , 70
        , 80
        , 90
        , 95
        , 99
    ]
%}

with
    agg_stats as (
        select
            cast(batch_run_date as date) as day_agg
            , ceil(cast(max(
                fee_charged
                / case
                    when new_max_fee is null then txn_operation_count
                    else (txn_operation_count + 1)
                end
            ) as bigint)) as fee_charged_max
            , ceil(cast(min(
                fee_charged
                / case
                    when new_max_fee is null then txn_operation_count
                    else (txn_operation_count + 1)
                end
            ) as bigint)) as fee_charged_min
            , approx_top_count(
                fee_charged
                / case
                    when new_max_fee is null then txn_operation_count
                    else (txn_operation_count + 1)
                end
                , 1
            )[offset(0)
            ] as fee_charged_mode
            , ceil(cast(max(
                coalesce(new_max_fee, max_fee
                )
                / case
                    when new_max_fee is null then txn_operation_count
                    else (txn_operation_count + 1)
                end
            ) as bigint)) as max_fee_max
            , ceil(cast(min(
                coalesce(new_max_fee, max_fee
                )
                / case
                    when new_max_fee is null then txn_operation_count
                    else (txn_operation_count + 1)
                end
            ) as bigint)) as max_fee_min
            , approx_top_count(
                coalesce(new_max_fee, max_fee)
                / case
                    when new_max_fee is null then txn_operation_count
                    else (txn_operation_count + 1)
                end
                , 1
            )[offset(0)
            ] as max_fee_mode
            {{ percentile_iteration(percentiles) }}
            , min(ledger_sequence) as min_ledger_sequence
            , max(ledger_sequence) as max_ledger_sequence
        from {{ ref('stg_history_transactions') }}
        where
            cast(batch_run_date as date) < date_add(date('{{ dbt_airflow_macros.ds() }}'), interval 2 day)
            and date(closed_at) < date_add(date('{{ dbt_airflow_macros.ds() }}'), interval 1 day)
            {% if is_incremental() %}
                and cast(batch_run_date as date) >= date('{{ dbt_airflow_macros.ds() }}') -- batch run is the min bound of a batch
                and date(closed_at) >= date('{{ dbt_airflow_macros.ds() }}')
            {% endif %}
        group by cast(batch_run_date as date)
    )

    , surge_price_ledgers as (
        select
            cast(batch_run_date as date) as day_agg
            , ledger_sequence
            , case
                when (txn_operation_count + if(fee_account is not null, 1, 0)) * 100 < fee_charged
                    then 1
                else 0
            end as surge_price_ind
        from {{ ref('stg_history_transactions') }}
        where
            cast(batch_run_date as date) < date_add(date('{{ dbt_airflow_macros.ds() }}'), interval 2 day)
            and date(closed_at) < date_add(date('{{ dbt_airflow_macros.ds() }}'), interval 1 day)
            {% if is_incremental() %}
                and cast(batch_run_date as date) >= date('{{ dbt_airflow_macros.ds() }}') -- batch run is the min bound of a batch
                and date(closed_at) >= date('{{ dbt_airflow_macros.ds() }}')
            {% endif %}
        group by
            cast(batch_run_date as date)
            , ledger_sequence
            , surge_price_ind
    )

    , surge_stats as (
        select
            day_agg
            , count(ledger_sequence) as total_ledgers
            , sum(surge_price_ind) as surge_price_count
        from surge_price_ledgers
        group by day_agg
    )

    , renaming as (
        select
            agg_stats.day_agg
            , agg_stats.fee_charged_p10
            , agg_stats.fee_charged_p20
            , agg_stats.fee_charged_p30
            , agg_stats.fee_charged_p40
            , agg_stats.fee_charged_p50
            , agg_stats.fee_charged_p60
            , agg_stats.fee_charged_p70
            , agg_stats.fee_charged_p80
            , agg_stats.fee_charged_p90
            , agg_stats.fee_charged_p95
            , agg_stats.fee_charged_p99
            , agg_stats.fee_charged_max
            , agg_stats.fee_charged_min
            , ceil(agg_stats.fee_charged_mode.value) as fee_charged_mode
            , agg_stats.max_fee_p10
            , agg_stats.max_fee_p20
            , agg_stats.max_fee_p30
            , agg_stats.max_fee_p40
            , agg_stats.max_fee_p50
            , agg_stats.max_fee_p60
            , agg_stats.max_fee_p70
            , agg_stats.max_fee_p80
            , agg_stats.max_fee_p90
            , agg_stats.max_fee_p95
            , agg_stats.max_fee_p99
            , agg_stats.max_fee_max
            , agg_stats.max_fee_min
            , ceil(agg_stats.max_fee_mode.value) as max_fee_mode
            , agg_stats.min_ledger_sequence
            , agg_stats.max_ledger_sequence
            , surge_stats.total_ledgers
            , 100 * (surge_stats.surge_price_count / surge_stats.total_ledgers) as surge_price_pct
        from agg_stats
        inner join
            surge_stats on
        agg_stats.day_agg = surge_stats.day_agg
    )

select distinct *
from renaming
