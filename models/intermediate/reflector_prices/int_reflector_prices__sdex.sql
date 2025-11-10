{% set meta_config = {
    "materialized": "table",
    "tags": ["reflector_prices"],
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

with
    asset_coding as (
        select distinct
            json_extract_scalar(storage_item, '$.key.address') as asset_contract_id
            , cast(json_extract_scalar(storage_item, '$.val.u32') as int) as asset_index
        from {{ ref('contract_data_snapshot') }}
        , unnest(json_extract_array(val_decoded, '$.contract_instance.storage')) as storage_item
        where
            contract_id = 'CALI2BYU2JE6WVRUFYTS6MSBNEHGJ35P4AVCZYF3B6QOE3QKOB2PLE6M'
            and contract_durability = 'ContractDataDurabilityPersistent'
            and json_extract_scalar(storage_item, '$.key.address') is not null
    )

    , price_data as (
        select
            closed_at
            , cast(right(json_extract_scalar(key_decoded, '$.u128'), 2) as int) as asset_index
            , cast(json_extract_scalar(val_decoded, '$.i128') as float64) as price
        from {{ ref('contract_data_snapshot') }}
        where
            contract_id = 'CALI2BYU2JE6WVRUFYTS6MSBNEHGJ35P4AVCZYF3B6QOE3QKOB2PLE6M'
            and contract_durability != 'ContractDataDurabilityPersistent'
    )

    , joined as (
        select
            stg_assets.asset_code
            , stg_assets.asset_type
            , stg_assets.asset_issuer
            , asset_coding.asset_contract_id
            , price_data.closed_at as updated_at
            , price_data.price * power(10, -14) as open_usd
            , price_data.price * power(10, -14) as high_usd
            , price_data.price * power(10, -14) as low_usd
            , price_data.price * power(10, -14) as close_usd
        from price_data
        left join asset_coding
            on price_data.asset_index = asset_coding.asset_index
        left join {{ ref('stg_assets') }} as stg_assets
            on asset_coding.asset_contract_id = stg_assets.asset_contract_id
    )

select *
from joined
