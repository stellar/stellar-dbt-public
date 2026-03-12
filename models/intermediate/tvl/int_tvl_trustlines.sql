{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["day", "account_id", "asset_code", "asset_issuer"],
    "tags": ["tvl"]
} %}

-- The earliest asset pricing data is at 2022-08-08 from stellar.expert.
{% set full_refresh_date = '2022-08-08' %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

-- To find the asset TVL for a given day
--  * Get all trustline entries <= day
--  * Get the current value of selling liabilities of the trustline for that day
--  * Sum all the values for that day for all assets

-- Dates that asset to TVL amount should be calculated for
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
            and t.closed_at < timestamp(date('{{ var("batch_end_date") }}'))
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
