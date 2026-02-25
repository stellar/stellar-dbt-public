{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["day_agg"],
    "tags": ["fee_stats"],
    "partition_by": {
        "field": "day_agg"
        , "data_type": "date"
        , "granularity": "month"}
} %}

{{ config(
    meta=meta_config,
    **meta_config,
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
            cast(batch_run_date as date) as day_agg -- agg by batch run date, daily
            -- each ceil rounds up
            , ceil(cast(max(
                fee_charged
                / case
                    when new_max_fee is null then txn_operation_count --add 1 to txn op count if fee bump occurs (i.e. new_max_fee not null)
                    else (txn_operation_count + 1)
                end
            ) as bigint)) as fee_charged_max -- grabs max fee charged per op count for the day - what was actually charged
            , ceil(cast(min(
                fee_charged
                / case
                    when new_max_fee is null then txn_operation_count --add 1 to txn op count if fee bump occurs (i.e. new_max_fee not null)
                    else (txn_operation_count + 1)
                end
            ) as bigint)) as fee_charged_min -- grabs min fee charged per op count for the day
            , approx_top_count( -- grab frequent values in this column for the day
                fee_charged
                / case
                    when new_max_fee is null then txn_operation_count --add 1 to txn op count if fee bump occurs (i.e. new_max_fee not null)
                    else (txn_operation_count + 1)
                end
                , 1
            )[offset(0)
            ] as fee_charged_mode -- grabs mode fee charger per op count for the day
            , ceil(cast(max(
                coalesce(new_max_fee, max_fee
                )
                / case
                    when new_max_fee is null then txn_operation_count
                    else (txn_operation_count + 1)
                end
            ) as bigint)) as max_fee_max -- grabs max fee per op count for the day - what could have been charged (what they were willing to pay)
            , ceil(cast(min(
                coalesce(new_max_fee, max_fee
                )
                / case
                    when new_max_fee is null then txn_operation_count
                    else (txn_operation_count + 1)
                end
            -- grabs min fee per op count for the day - min of what could have been charged (what they were willing to pay)
            ) as bigint)) as max_fee_min
            , approx_top_count(
                coalesce(new_max_fee, max_fee)
                / case
                    when new_max_fee is null then txn_operation_count
                    else (txn_operation_count + 1)
                end
                , 1
            )[offset(0)
            ] as max_fee_mode -- grabs mode fee they were willing to pay per op count for the day
            {{ percentile_iteration(percentiles) }}
            -- grabs fee per op count percentiles for the day - what was actually charged and what could have been charged

            , min(ledger_sequence) as min_ledger_sequence
            , max(ledger_sequence) as max_ledger_sequence
        from {{ ref('stg_history_transactions') }}
        where
            batch_run_date < datetime(date('{{ var("batch_end_date") }}'))
        {% if is_incremental() %}
                and batch_run_date >= datetime(date('{{ var("batch_start_date") }}')) -- batch run is the min bound of a batch
            {% endif %}
        group by cast(batch_run_date as date)
    )

    , surge_price_ledgers as (
        select
            cast(batch_run_date as date) as day_agg
            , ledger_sequence
            , case
                when (txn_operation_count + if(fee_account is not null, 1, 0)) * 100 < fee_charged
                    then 1 -- checks if the fee they paid is more than the min fee, min fee is 100 stroops per op
                    -- if it is, then this ledger marked as surge
                else 0
            end as surge_price_ind
        from {{ ref('stg_history_transactions') }}
        where
            batch_run_date < datetime(date('{{ var("batch_end_date") }}'))
        {% if is_incremental() %}
                and batch_run_date >= datetime(date('{{ var("batch_start_date") }}')) -- batch run is the min bound of a batch
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
            , sum(surge_price_ind) as surge_price_count --num of ledgers with surge price
        from surge_price_ledgers
        group by day_agg
    )

    , renaming as (
        select
            agg_stats.day_agg
            , agg_stats.fee_charged_p10 -- percentiles for what was charged
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
            , agg_stats.max_fee_p10 -- percentiles for what could have been charged (what they were willing to pay)
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
            , agg_stats.min_ledger_sequence -- min ledger sequence for the day
            , agg_stats.max_ledger_sequence -- max ledger sequence for the day
            , surge_stats.total_ledgers
            , 100 * (surge_stats.surge_price_count / surge_stats.total_ledgers) as surge_price_pct -- percentage of ledgers with surge price
            , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
        from agg_stats
        inner join
            surge_stats on
        agg_stats.day_agg = surge_stats.day_agg
    )

select distinct *
from renaming
