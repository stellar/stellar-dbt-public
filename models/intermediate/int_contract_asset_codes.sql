{% set meta_config = {
    "tags": ["assets"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

with
    asset_per_contract as (
        select
            asset_contract_id as contract_id
            , max(case when asset_code is not null and asset_code != '' then asset_code end) as asset_code
            , max(case when asset_issuer is not null and asset_issuer != '' then asset_issuer end) as asset_issuer
            , max(case when asset_type is not null and asset_type != '' then asset_type end) as asset_type
        from {{ ref('stg_assets') }}
        where asset_contract_id is not null
        group by 1
    )

    , metadata as (
        select
            contract_id
            , symbol
            , `name`
            , `decimal`
        from {{ ref('int_asset_metadata') }}
    )

    , all_contracts as (
        select contract_id from asset_per_contract
        union distinct
        select contract_id from metadata
    )

select
    c.contract_id
    , coalesce(a.asset_code, m.symbol, c.contract_id) as asset_code
    , a.asset_issuer
    , a.asset_type
    , m.symbol
    , m.`name`
    , m.`decimal`
    , case
        when a.asset_code is not null then 'sac'
        when m.symbol is not null then 'metadata'
        else 'contract_id'
    end as asset_code_source
from all_contracts as c
left join asset_per_contract as a
    on c.contract_id = a.contract_id
left join metadata as m
    on c.contract_id = m.contract_id
