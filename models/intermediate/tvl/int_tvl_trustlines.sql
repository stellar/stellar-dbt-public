{% set batch_size = 'year' if flags.FULL_REFRESH else 'day' %}

{# `begin` is 2022-08-08: the earliest asset pricing data from stellar.expert. #}
{% set meta_config = {
    "materialized": "incremental",
    "incremental_strategy": "microbatch",
    "event_time": "day",
    "batch_size": batch_size,
    "concurrent_batches": flags.FULL_REFRESH,
    "begin": "2022-08-08",
    "partition_by": {
        "field": "day"
        , "data_type": "date"
        , "granularity": "day"
        , "copy_partitions": flags.FULL_REFRESH},
    "tags": ["tvl"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

-- To find the asset TVL for a given day
--  * Get each trustline's state as of that day from the SCD-2 trustlines_snapshot
--    (valid_from/valid_to), rather than reconstructing it from the raw change log
--  * Take the selling liabilities of the trustline for that day
--  * Sum all the values for that day for all assets

with
    -- Microbatch supplies the batch window via model.batch (set at run time).
    dt as (
        select dates as day
        from unnest(generate_date_array(date(timestamp('{{ model.batch.event_time_start }}')), date_sub(least(date(timestamp('{{ model.batch.event_time_end }}')), date('{{ var("batch_end_date") }}')), interval 1 day))) as dates
    )

    , filtered_tl as (
        select
            tl.account_id
            , tl.asset_type
            , tl.asset_code
            , tl.asset_issuer
            , tl.selling_liabilities
            , tl.valid_from
            , tl.valid_to
        from {{ ref('trustlines_snapshot') }} as tl
        where
            tl.deleted is false
            and tl.valid_from < timestamp(date_add((select max(day) from dt), interval 1 day))
            and (tl.valid_to is null or tl.valid_to >= timestamp((select min(day) from dt)))
    )

    , daily_trustline_tvl as (
        select
            dt.day
            , tl.account_id
            , tl.asset_type
            , tl.asset_code
            , tl.asset_issuer
            , sum(tl.selling_liabilities) as trustlines_tvl
        from dt
        inner join filtered_tl as tl
            on
            timestamp(dt.day) >= timestamp_trunc(tl.valid_from, day)
            and (timestamp(date_add(dt.day, interval 1 day)) <= timestamp_trunc(tl.valid_to, day) or tl.valid_to is null)
        group by 1, 2, 3, 4, 5
    )

select *
from daily_trustline_tvl
