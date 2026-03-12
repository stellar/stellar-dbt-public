{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["day", "account_id", "asset_code", "asset_issuer"],
    "tags": ["tvl"]
} %}

{% set tvl_start_date = var("tvl_start_date", none) %}
{% set tvl_end_date = var("tvl_end_date", none) %}
-- The earliest asset pricing data is at 2022-08-08 from stellar.expert.
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

-- To find the asset TVL in USD for a given day
--  * Get all trustline entries <= day
--  * Get the current value of selling liabilities of the trustline for that day for non tier 0 assets
--  * Convert the asset selling liabilities to USD with the partnership_asset_prices
--  * Sum all the values for that day for all assets

-- Dates that asset to USD TVL amount should be calculated for
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

    , filter_trustlines as (
        select
            t.account_id
            , t.asset_code
            , t.asset_issuer
            , t.selling_liabilities
            , t.deleted
            , t.closed_at
        from {{ ref('stg_trust_lines') }} as t
        where
            true
            {% if not is_incremental() %}
                and t.closed_at < timestamp(date_add(date('{{ full_refresh_date }}'), interval 1 day))
            {% else %}
                {% if tvl_start_date is not none and tvl_end_date is not none %}
        and t.closed_at < timestamp(date_add(date('{{ tvl_end_date }}'), interval 1 day))
      {% else %}
                    and t.closed_at < timestamp(date('{{ var("batch_end_date") }}'))
                {% endif %}
            {% endif %}
    )

    , trustline_tvl_per_day as (
        select
            d.day
            , t.account_id
            , t.asset_code
            , t.asset_issuer
            , array_agg(t.selling_liabilities order by t.closed_at desc)[offset(0)] as tvl
            , array_agg(t.deleted order by t.closed_at desc)[offset(0)] as deleted
        from date_range as d
        inner join filter_trustlines as t
            on t.closed_at < timestamp(date_add(d.day, interval 1 day))
        where
            true
            and deleted = false
        group by 1, 2, 3, 4
    )

    , daily_trustline_tvl as (
        select
            day
            , account_id
            , asset_code
            , asset_issuer
            , sum(tvl) as trustlines_tvl
        from trustline_tvl_per_day
        group by 1, 2, 3, 4
    )

select *
from daily_trustline_tvl
