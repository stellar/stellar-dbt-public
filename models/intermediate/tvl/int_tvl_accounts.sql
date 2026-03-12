{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["day", "account_id"],
    "tags": ["tvl"]
} %}

{% set tvl_start_date = var("tvl_start_date", none) %}
{% set tvl_end_date = var("tvl_end_date", none) %}
-- The earliest pricing data is at 2022-08-08 from stellar.expert for assets.
-- We do have XLM:USD data before 2022-08-08 but it would not be useful for TVL calculation
-- without asset pricing data as well.
-- Full history is too large to fully refresh so the initial table will be capped at a single day
-- where backfilling should be done using the tvl_start_date/tvl_end_date variables
{% set full_refresh_date = '2022-08-08' %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

-- TODO: With the new batch_start_date and batch_end_date parameters there probably isn't a need
-- to define the custom tvL_start_date and tvl_end_date parameters and special logic associated with
-- them. We should refactor the tvl model SQL to handle the backfill/incremental runs just like all
-- our other dbt models.

-- To find the XLM TVL in USD for a given day
--  * Get all account entries <= day
--  * Get the current value of the account_id for that day
--  * Sum all the values for that day for all accounts
--  * Multiply by the XLM:USD value for that day

-- Dates that XLM to USD TVL amount should be calculated for
with
    date_range as (
        select day
        {% if not is_incremental() %}
            from unnest(generate_date_array(date('{{ full_refresh_date }}'), date('{{ full_refresh_date }}'))) as day
        {% else %}
            {% if tvl_start_date is not none and tvl_end_date is not none %}
      from unnest(GENERATE_DATE_ARRAY(date('{{ tvl_start_date }}'), date('{{ tvl_end_date }}'))) as day
    {% else %}
                from unnest(generate_date_array(date('{{ var("batch_start_date") }}'), date_sub(date('{{ var("batch_end_date") }}'), interval 1 day))) as day
            {% endif %}
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
            {% if not is_incremental() %}
                and a.closed_at < timestamp(date_add(date('{{ full_refresh_date }}'), interval 1 day))
            {% else %}
                {% if tvl_start_date is not none and tvl_end_date is not none %}
          and a.closed_at < timestamp(date_add(date('{{ tvl_end_date }}'), interval 1 day))
        {% else %}
                    and a.closed_at < timestamp(date('{{ var("batch_end_date") }}'))
                {% endif %}
            {% endif %}
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
            , sum(tvl) as total_tvl
        from daily_account_xlm_tvl
        group by 1, 2
        order by 1
    )

select *
from daily_xlm_tvl
