{% set batch_size = env_var('DBT_MICROBATCH_BATCH_SIZE', '') or ('year' if flags.FULL_REFRESH else 'day') %}

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

-- To find the XLM TVL for a given day
--  * Get each account's state as of that day from the SCD-2 accounts_snapshot
--    (valid_from/valid_to), rather than reconstructing it from the raw change log
--  * Take the XLM selling liabilities of the account for that day
--  * Sum all the values for that day for all accounts

{# model.batch is only set at microbatch run time; fall back to the batch
   vars so parse/compile (e.g. `dbt compile` in CI) renders without a batch
   context. #}
{% set window_start = model.batch.event_time_start if model.batch else var("batch_start_date") %}
{% set window_end = model.batch.event_time_end if model.batch else var("batch_end_date") %}

with
    -- Microbatch supplies the batch window via model.batch (set at run time).
    dt as (
        select dates as day
        from unnest(generate_date_array(date(timestamp('{{ window_start }}')), date_sub(least(date(timestamp('{{ window_end }}')), date('{{ var("batch_end_date") }}')), interval 1 day))) as dates
    )

    , filtered_acc as (
        select
            acc.account_id
            , acc.selling_liabilities
            , acc.valid_from
            , acc.valid_to
        from {{ ref('accounts_snapshot') }} as acc
        where
            acc.deleted is false
            and acc.valid_from < timestamp(date_add((select max(day) from dt), interval 1 day))
            and (acc.valid_to is null or acc.valid_to >= timestamp((select min(day) from dt)))
    )

    , daily_xlm_tvl as (
        select
            dt.day
            , acc.account_id
            , sum(acc.selling_liabilities) as accounts_tvl
        from dt
        inner join filtered_acc as acc
            on
            timestamp(dt.day) >= timestamp_trunc(acc.valid_from, day)
            and (timestamp(date_add(dt.day, interval 1 day)) <= timestamp_trunc(acc.valid_to, day) or acc.valid_to is null)
        group by 1, 2
    )

select *
from daily_xlm_tvl
