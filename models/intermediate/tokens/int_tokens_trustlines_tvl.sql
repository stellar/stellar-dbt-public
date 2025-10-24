{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["day", "account_id", "asset_code", "asset_issuer"]
} %}

-- Set the lower bound of when the network started, '2015-09-30'
{% set full_refresh_date = '2015-09-30' %}


{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

-- To find the asset TVL in USD for a given day
--  * Get all trustline entries <= day
--  * Get the current value of selling liabilities of the trustline for that day for non tier 0 assets

-- Dates that asset to USD TVL amount should be calculated for
with
    date_range as (
        select day
        {% if not is_incremental() %}
            from unnest(generate_date_array(date('{{ full_refresh_date }}'), date('{{ dbt_airflow_macros.ts() }}'))) as day
        {% else %}
    from unnest(generate_date_array(date('{{ dbt_airflow_macros.ts() }}'), date('{{ dbt_airflow_macros.ts() }}'))) as day
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
        inner join assets as a
            on t.asset_code = a.asset_code
            and t.asset_issuer = a.asset_issuer
    )

    , trustline_tvl_per_day as (
        select
            d.day
            , t.account_id
            , t.asset_code
            , t.asset_issuer
            , t.asset_type
            , array_agg(t.selling_liabilities order by t.closed_at desc)[offset(0)] as amount_raw
            , array_agg(t.deleted order by t.closed_at desc)[offset(0)] as deleted
        from date_range as d
        inner join filter_trustlines as t
            on date(t.closed_at) <= d.day
        group by 1, 2, 3, 4
    )

select
    day
    , account_id
    , asset_code
    , asset_issuer
    , asset_type
    , amount_raw
from trustline_tvl_per_day
group by 1, 2, 3, 4
