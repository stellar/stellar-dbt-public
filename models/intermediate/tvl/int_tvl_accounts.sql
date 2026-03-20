{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["day", "account_id"],
    "tags": ["tvl"]
} %}

-- The earliest pricing data is at 2022-08-08 from stellar.expert for assets.
{% set full_refresh_date = '2022-08-08' %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

-- To find the XLM TVL for a given day
--  * Get all account entries <= day
--  * Get the current value of the account_id for that day
--  * Sum all the values for that day for all accounts

-- Dates that XLM TVL amount should be calculated for
with
    date_range as (
        select day
        {% if is_incremental() %}
            from
                unnest(generate_date_array(date('{{ var("batch_start_date") }}'), date_sub(date('{{ var("batch_end_date") }}'), interval 1 day)))
                    as day
        {% else %}
            from unnest(generate_date_array(date('{{ full_refresh_date }}'), date_sub(date('{{ var("batch_end_date") }}'), interval 1 day))) as day
        {% endif %}
    )

    , xlm_tvl_per_day as (
        select
            d.day
            , a.account_id
            , array_agg(a.selling_liabilities order by a.closed_at desc)[offset(0)] as tvl
            , array_agg(a.deleted order by a.closed_at desc)[offset(0)] as deleted
        from date_range as d
        inner join {{ ref('stg_accounts') }} as a
            on a.closed_at < timestamp(date_add(d.day, interval 1 day))
            and a.closed_at < timestamp(date('{{ var("batch_end_date") }}'))
        group by 1, 2
    )

    , daily_account_xlm_tvl as (
        select
            day
            , account_id
            , tvl
        from xlm_tvl_per_day
        where
            true
            and deleted = false
    )

    , daily_xlm_tvl as (
        select
            day
            , account_id
            , sum(tvl) as accounts_tvl
        from daily_account_xlm_tvl
        group by 1, 2
    )

select *
from daily_xlm_tvl
