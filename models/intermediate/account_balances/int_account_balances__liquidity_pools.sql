{% set batch_size = microbatch_batch_size() %}

{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='day',
    batch_size=batch_size,
    concurrent_batches=true,
    begin=microbatch_begin('2015-09-30'),
    partition_by={
         "field": "day"
        , "data_type": "date"
        , "granularity": "day"
        , "copy_partitions": true
    },
    cluster_by=["asset_type", "asset_code", "asset_issuer"],
)}}

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
            , tl.balance
            , tl.liquidity_pool_id
            , tl.valid_from
            , tl.valid_to
        from {{ ref('trustlines_snapshot') }} as tl
        where
            tl.liquidity_pool_id != ''
            and tl.deleted is false
            and tl.valid_from < timestamp(date_add((select max(day) from dt), interval 1 day))
            and (tl.valid_to is null or tl.valid_to >= timestamp((select min(day) from dt)))
    )

    , filtered_lp as (
        select lp.*
        from {{ ref('liquidity_pools_snapshot') }} as lp
        where
            lp.deleted is false
            and lp.valid_from < timestamp(date_add((select max(day) from dt), interval 1 day))
            and (lp.valid_to is null or lp.valid_to >= timestamp((select min(day) from dt)))
    )

    , all_tl as (
        select
            dt.day
            , ftl.* except (valid_from, valid_to)
        from dt
        inner join filtered_tl as ftl
            on
            timestamp(dt.day) >= timestamp_trunc(ftl.valid_from, day)
            and (timestamp(date_add(dt.day, interval 1 day)) <= timestamp_trunc(ftl.valid_to, day) or ftl.valid_to is null)
    )

    , all_lp as (
        select
            dt.day
            , flp.* except (valid_from, valid_to)
        from dt
        inner join filtered_lp as flp
            on
            timestamp(dt.day) >= timestamp_trunc(flp.valid_from, day)
            and (timestamp(date_add(dt.day, interval 1 day)) <= timestamp_trunc(flp.valid_to, day) or flp.valid_to is null)
    )

    , joined as (
        select
            all_tl.day
            , all_tl.account_id
            , all_lp.asset_a_type
            , all_lp.asset_a_issuer
            , all_lp.asset_a_code
            , (all_tl.balance / all_lp.pool_share_count) * all_lp.asset_a_amount as asset_a_amount
            , all_lp.asset_b_type
            , all_lp.asset_b_issuer
            , all_lp.asset_b_code
            , (all_tl.balance / all_lp.pool_share_count) * all_lp.asset_b_amount as asset_b_amount
        from all_tl
        left join all_lp
            on all_tl.liquidity_pool_id = all_lp.liquidity_pool_id
            and all_tl.day = all_lp.day
        where all_lp.pool_share_count != 0
    )

    , account_from_balances as (
        select
            j.day
            , j.account_id
            , j.asset_a_type as asset_type
            , j.asset_a_issuer as asset_issuer
            , j.asset_a_code as asset_code
            , sum(j.asset_a_amount) as balance
        from joined as j
        group by 1, 2, 3, 4, 5
    )

    , account_to_balances as (
        select
            j.day
            , j.account_id
            , j.asset_b_type as asset_type
            , j.asset_b_issuer as asset_issuer
            , j.asset_b_code as asset_code
            , sum(j.asset_b_amount) as balance
        from joined as j
        group by 1, 2, 3, 4, 5
    )

    , all_balances as (
        select * from account_from_balances
        union all
        select * from account_to_balances
    )

    , aggregate as (
        select
            day
            , account_id
            , asset_type
            , if(asset_type = 'native', 'XLM', asset_issuer) as asset_issuer
            , if(asset_type = 'native', 'XLM', asset_code) as asset_code
            , sum(balance) as balance
        from all_balances
        group by 1, 2, 3, 4, 5
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
