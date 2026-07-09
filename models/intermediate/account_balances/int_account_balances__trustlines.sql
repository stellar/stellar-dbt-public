{% set batch_size = 'year' if flags.FULL_REFRESH else 'day' %}

{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='day',
    batch_size=batch_size,
    concurrent_batches=flags.FULL_REFRESH,
    begin='2023-01-01',
    partition_by={
         "field": "day"
        , "data_type": "date"
        , "granularity": "day"
        , "copy_partitions": flags.FULL_REFRESH
    },
    cluster_by=["asset_type", "asset_code", "asset_issuer"],
) }}

with
    dt as (
        select dates as day
        -- Microbatch supplies the batch window via model.batch; the else branch
        -- is only a compile-time placeholder (model.batch is unset outside a run).
        {% if model.batch %}
            from unnest(generate_date_array(date(timestamp('{{ model.batch.event_time_start }}')), date_sub(date(timestamp('{{ model.batch.event_time_end }}')), interval 1 day))) as dates
        {% else %}
            from unnest(generate_date_array('2023-01-01', '2023-01-01')) as dates
        {% endif %}
    )

    , filtered_tl as (
        select
            tl.account_id
            , tl.asset_type
            , tl.asset_issuer
            , tl.asset_code
            , tl.balance
            , tl.valid_from
            , tl.valid_to
        from {{ ref('trustlines_snapshot') }} as tl
        where
            tl.liquidity_pool_id = ''
            and tl.deleted is false
            and tl.valid_from < timestamp(date_add((select max(day) from dt), interval 1 day))
            and (tl.valid_to is null or tl.valid_to >= timestamp((select min(day) from dt)))
    )

    , filtered_acc as (
        select
            acc.account_id
            , 'native' as asset_type
            , 'XLM' as asset_issuer
            , 'XLM' as asset_code
            , acc.balance
            , acc.valid_from
            , acc.valid_to
        from {{ ref('accounts_snapshot') }} as acc
        where
            acc.deleted is false
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
    -- Note: There will be some null contract_ids from this trustlines aggregate
    -- This is because there are trustlines that have been created for assets that have had
    -- zero asset value movement meaning they won't have any events in token_transfers.
    -- Because there are no events in token_transfers there is nothing for stg_assets to create
    -- the asset --> contract_id association hence there being null contract_ids in this agg.
    -- This will be fixed in the future when stellar-etl adds contract_ids for assets.
    , a.asset_contract_id as contract_id
    , agg.balance
from aggregate as agg
left join {{ ref('stg_assets') }} as a
    on agg.asset_type = a.asset_type
    and agg.asset_code = a.asset_code
    and agg.asset_issuer = a.asset_issuer
