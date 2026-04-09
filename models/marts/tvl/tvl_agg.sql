{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["day", "asset_code", "asset_issuer", "asset_type"],
    "tags": ["tvl"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

with
    accounts_tvl as (
        select
            day
            , 'native' as asset_type
            , 'XLM' as asset_code
            , 'XLM' as asset_issuer
            , sum(accounts_tvl) as accounts_tvl
        from {{ ref('int_tvl_accounts') }}
        group by 1, 2, 3, 4
    )

    , trustlines_tvl as (
        select
            day
            , asset_type
            , asset_code
            , asset_issuer
            , sum(trustlines_tvl) as trustlines_tvl
        from {{ ref('int_tvl_trustlines') }}
        group by 1, 2, 3, 4
    )

    , liquidity_pools_tvl as (
        select
            day
            , asset_type
            , asset_code
            , asset_issuer
            , sum(liquidity_pool_balance) as liquidity_pools_tvl
        from {{ ref('asset_balances__daily_agg') }}
        group by 1, 2, 3, 4
    )

    , combined as (
        select
            coalesce(a.day, t.day, l.day) as day
            , coalesce(a.asset_type, t.asset_type, l.asset_type) as asset_type
            , coalesce(a.asset_code, t.asset_code, l.asset_code) as asset_code
            , coalesce(a.asset_issuer, t.asset_issuer, l.asset_issuer) as asset_issuer
            , coalesce(a.accounts_tvl, 0) as accounts_tvl
            , coalesce(t.trustlines_tvl, 0) as trustlines_tvl
            , coalesce(l.liquidity_pools_tvl, 0) as liquidity_pools_tvl
            , coalesce(a.accounts_tvl, 0)
            + coalesce(t.trustlines_tvl, 0)
            + coalesce(l.liquidity_pools_tvl, 0) as total_tvl
        from accounts_tvl as a
        full outer join trustlines_tvl as t
            on a.day = t.day
            and a.asset_type = t.asset_type
            and a.asset_code = t.asset_code
            and a.asset_issuer = t.asset_issuer
        full outer join liquidity_pools_tvl as l
            on coalesce(a.day, t.day) = l.day
            and coalesce(a.asset_type, t.asset_type) = l.asset_type
            and coalesce(a.asset_code, t.asset_code) = l.asset_code
            and coalesce(a.asset_issuer, t.asset_issuer) = l.asset_issuer
    )

    , final as (
        select
            combined.day
            , combined.asset_type
            , combined.asset_code
            , combined.asset_issuer
            , a.asset_contract_id as contract_id
            , combined.accounts_tvl
            , combined.trustlines_tvl
            , combined.liquidity_pools_tvl
            , combined.total_tvl
        from combined
        left join {{ ref('stg_assets') }} as a
            on combined.asset_type = a.asset_type
            and combined.asset_code = a.asset_code
            and combined.asset_issuer = a.asset_issuer
    )

select *
from final
