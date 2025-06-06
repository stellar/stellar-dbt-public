{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["day", "account_id", "asset"]
} %}

-- Set the lower bound of when the network started, '2015-09-30'
{% set full_refresh_date = '2015-09-30' %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

-- To find the XLM TVL in USD for a given day
--  * Get all account entries <= day
--  * Get the current value of the account_id for that day

-- Build a date spine to fill all dates for an account even 
-- if there was no account activity for a given date
with
    date_range as (
        select day
        {% if not is_incremental() %}
            from unnest(generate_date_array(date('{{ full_refresh_date }}'), date('{{ dbt_airflow_macros.ts() }}'))) as day
        {% else %}
    from unnest(generate_date_array(date('{{ dbt_airflow_macros.ts() }}'), date('{{ dbt_airflow_macros.ts() }}'))) as day
        {% endif %}
    )

    , xlm_tvl_per_day as (
        select
            d.day
            , a.account_id
            , array_agg(a.selling_liabilities order by a.closed_at desc)[offset(0)] as amount_raw
            , array_agg(a.deleted order by a.closed_at desc)[offset(0)] as deleted
        from date_range as d
        inner join {{ ref('stg_accounts') }} as a
            on date(a.closed_at) <= d.day
        group by 1, 2
    )

    , daily_account_xlm_tvl_raw as (
        select
            day
            , account_id
            , 'native' as asset
            , '' as asset_code
            , '' as asset_issuer
            , 'native' as asset_type
            , amount_raw
        from xlm_tvl_per_day
        where
            true
            and deleted = false
    )

select *
from daily_account_xlm_tvl_raw
