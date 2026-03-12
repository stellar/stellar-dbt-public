{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["day"],
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
            , sum(accounts_tvl) as accounts_tvl
        from {{ ref('int_tvl_accounts') }}
        group by 1
    )

    , trustlines_tvl as (
        select
            day
            , sum(trustlines_tvl) as trustlines_tvl
        from {{ ref('int_tvl_trustlines') }}
        group by 1
    )

    , combined as (
        select
            a.day
            , a.accounts_tvl
            , t.trustlines_tvl
            , a.accounts_tvl + t.trustlines_tvl as total_tvl
        from accounts_tvl as a
        inner join trustlines_tvl as t
            on a.day = t.day
    )

select *
from combined
