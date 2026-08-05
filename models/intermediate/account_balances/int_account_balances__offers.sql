{% set batch_size = microbatch_batch_size() %}

{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='day',
    batch_size=batch_size,
    concurrent_batches=true,
    begin=microbatch_begin('2021-01-01'),
    partition_by={
         "field": "day"
        , "data_type": "date"
        , "granularity": "day"
        , "copy_partitions": true
    },
    cluster_by=["asset_type", "asset_code", "asset_issuer"],
    )
}}

{# model.batch is only set at microbatch run time; fall back to the batch
   vars so parse/compile (e.g. `dbt compile` in CI) renders without a batch
   context. #}
{% set window_start = model.batch.event_time_start if model.batch else var("batch_start_date") %}
{% set window_end = model.batch.event_time_end if model.batch else var("batch_end_date") %}

with
    dt as (
        select dates as day
        -- Microbatch supplies the batch window via model.batch (set at run time).
        from unnest(generate_date_array(date(timestamp('{{ window_start }}')), date_sub(least(date(timestamp('{{ window_end }}')), date('{{ var("batch_end_date") }}')), interval 1 day))) as dates
    )

    , filtered_tl as (
        select
            tl.account_id
            , tl.asset_type
            , tl.asset_issuer
            , tl.asset_code
            , tl.selling_liabilities as balance
            , tl.valid_from
            , tl.valid_to
        from {{ ref('trustlines_snapshot') }} as tl
        where
            tl.deleted is false
            and tl.selling_liabilities > 0
            and tl.liquidity_pool_id = ''
            and tl.valid_from < timestamp(date_add((select max(day) from dt), interval 1 day))
            and (tl.valid_to is null or tl.valid_to >= timestamp((select min(day) from dt)))

    )

    , filtered_acc as (
        select
            acc.account_id
            , 'native' as asset_type
            , 'XLM' as asset_issuer
            , 'XLM' as asset_code
            , acc.selling_liabilities as balance
            , acc.valid_from
            , acc.valid_to
        from {{ ref('accounts_snapshot_v2') }} as acc
        where
            acc.deleted is false
            and acc.selling_liabilities > 0
            and acc.valid_from < timestamp(date_add((select max(day) from dt), interval 1 day))
            and (acc.valid_to is null or acc.valid_to >= timestamp((select min(day) from dt)))
    )


    , aggregate as (
        select
            dt.day
            , tl.account_id
            , tl.asset_type
            , tl.asset_issuer
            , tl.asset_code
            , tl.balance
        from dt
        inner join filtered_tl as tl
            on
            timestamp(dt.day) >= timestamp_trunc(tl.valid_from, day)
            and (timestamp(date_add(dt.day, interval 1 day)) <= timestamp_trunc(tl.valid_to, day) or tl.valid_to is null)

        union all

        select
            dt.day
            , acc.account_id
            , acc.asset_type
            , acc.asset_issuer
            , acc.asset_code
            , acc.balance
        from dt
        inner join filtered_acc as acc
            on
            timestamp(dt.day) >= timestamp_trunc(acc.valid_from, day)
            and (timestamp(date_add(dt.day, interval 1 day)) <= timestamp_trunc(acc.valid_to, day) or acc.valid_to is null)
    )

select
    agg.day
    , agg.account_id
    , agg.asset_type
    , agg.asset_issuer
    , agg.asset_code
    , a.asset_contract_id as contract_id
    , agg.balance
from aggregate as agg
left join {{ ref('stg_assets') }} as a
    on agg.asset_type = a.asset_type
    and agg.asset_code = a.asset_code
    and agg.asset_issuer = a.asset_issuer
