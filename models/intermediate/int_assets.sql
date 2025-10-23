{% set meta_config = {
    "dataset": "gold",
    "unique_key": ["contract_id"],
    "tags": ["assets"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

with
    base_asset_list as (
        select
            case when asset_type = 'native' then 'XLM' else asset_code end as asset_code
            , case when asset_type = 'native' then 'XLM' else asset_issuer end as asset_issuer
            , asset_type
            , contract_id
            , min(closed_at) as created_at
        from {{ ref('stg_token_transfers_raw') }}
        group by 1, 2, 3, 4
    )

select *
from base_asset_list
