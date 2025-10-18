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
            , asset
            , asset_code
            , asset_issuer
            , asset_type
            , sum(amount_raw) as tvl_amount_raw
        from {{ ref('int_tokens_accounts_tvl') }}
        group by 1
    )

    , trustlines_tvl as (
        select
            day
            , asset
            , asset_code
            , asset_issuer
            , asset_type
            , sum(amount_raw) as tvl_amount_raw
        from {{ ref('int_tokens_trustlines_tvl') }}
        group by 1
    )

    , merge_tvl as (
        select *
        from accounts_tvl
        union all
        select *
        from trustlines_tvl
    )

select
    day
    , asset
    , asset_code
    , asset_issuer
    , asset_type
    , sum(tvl_amount_raw) as tvl_amount_raw
from merge_tvl
group by 1, 2, 3, 4, 5
