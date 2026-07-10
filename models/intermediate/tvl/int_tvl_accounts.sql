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

-- To find the XLM TVL for a given day
--  * Get each account's state as of that day from the SCD-2 accounts_snapshot
--    (valid_from/valid_to), rather than reconstructing it from the raw change log
--  * Take the XLM selling liabilities of the account for that day
--  * Sum all the values for that day for all accounts

with
    -- Microbatch supplies the batch window via model.batch; the else branch
    -- is only a compile-time placeholder (model.batch is unset outside a run).
    dt as (
        select dates as day
        {% if model.batch %}
            from unnest(generate_date_array(date(timestamp('{{ model.batch.event_time_start }}')), date_sub(least(date(timestamp('{{ model.batch.event_time_end }}')), date('{{ var("batch_end_date") }}')), interval 1 day))) as dates
        {% else %}
            from unnest(generate_date_array('2022-08-08', '2022-08-08')) as dates
        {% endif %}
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
