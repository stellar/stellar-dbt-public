{% set meta_config = {
    "materialized": "table",
    "tags": ["reflector_prices"],
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

/*
    Reflector SDEX price data comes in two formats:

    OLD FORMAT (one price per row):
        key_decoded: {"u128":"32711699810280701686500556800002"}  -- last 2 digits = asset_index
        val_decoded: {"i128":"100006764875672"}                  -- the price

    NEW FORMAT (batch of prices per row):
        key_decoded: {"u64":"1773334500000"}
        val_decoded: {"map":[
            {"key":{"symbol":"mask"}, "val":{"bytes":"d6bf08..."}},   -- bitmask: which assets have updated prices
            {"key":{"symbol":"prices"},"val":{"vec":[{"i128":"..."},...]}}  -- prices (only for set bits in mask)
        ]}

    Mask decoding (LSB-first per byte):
        Each byte's bits map to asset indices. e.g. byte 0xD6 = 11010110:
        bit 0=0, bit 1=1, bit 2=1, bit 3=0, bit 4=1, bit 5=0, bit 6=1, bit 7=1
        → asset indices 1,2,4,6,7 have prices in the vec.
        The prices vec contains values only for set bits, in order.
*/

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
            and valid_to is null -- fetch only latest entry
    )

    , price_data_old_format as (
        select
            closed_at
            , cast(right(json_extract_scalar(key_decoded, '$.u128'), 2) as int) as asset_index
            , cast(json_extract_scalar(val_decoded, '$.i128') as float64) as price
        from {{ ref('contract_data_snapshot') }}
        where
            contract_id = 'CALI2BYU2JE6WVRUFYTS6MSBNEHGJ35P4AVCZYF3B6QOE3QKOB2PLE6M'
            and contract_durability != 'ContractDataDurabilityPersistent'
            and json_extract_scalar(key_decoded, '$.u128') is not null
    )

    , new_format_raw as (
        select
            closed_at
            , json_extract_scalar(
                json_extract_array(val_decoded, '$.map')[safe_offset(0)]
                , '$.val.bytes'
            ) as mask_hex
            , json_extract_array(
                json_extract(
                    json_extract_array(val_decoded, '$.map')[safe_offset(1)]
                    , '$.val.vec'
                )
            ) as prices_array
        from {{ ref('contract_data_snapshot') }}
        where
            contract_id = 'CALI2BYU2JE6WVRUFYTS6MSBNEHGJ35P4AVCZYF3B6QOE3QKOB2PLE6M'
            and contract_durability != 'ContractDataDurabilityPersistent'
            and json_extract_scalar(key_decoded, '$.u64') is not null
    )

    -- use mask to map each price in the vec to its actual asset_index
    , price_data_new_format as (
        select
            closed_at
            , asset_index
            , cast(json_extract_scalar(prices_array[safe_offset(vec_index)], '$.i128') as float64) as price
        from new_format_raw
            , unnest({{ find_changed_asset_indexes('mask_hex') }}) as asset_index with offset as vec_index
    )

    , price_data as (
        select * from price_data_old_format
        union all
        select * from price_data_new_format
    )

    , joined as (
        select distinct
            stg_assets.asset_code
            , stg_assets.asset_type
            , stg_assets.asset_issuer
            , asset_coding.asset_contract_id
            , price_data.closed_at as updated_at
            , price_data.price * power(10, -14) as price
        from price_data
        left join asset_coding
            on price_data.asset_index = asset_coding.asset_index
        left join {{ ref('stg_assets') }} as stg_assets
            on asset_coding.asset_contract_id = stg_assets.asset_contract_id
    )

    -- Calculate daily OHLC prices from the raw price data
    , ohlc as (
        {{
            calc_ohlc(
                relation = 'joined',
                ts_col = 'updated_at',
                price_col = 'price',
                partition_cols = ['asset_code', 'asset_issuer', 'asset_type', 'asset_contract_id'],
            )
        }}
    )

select *
from ohlc
