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
    Reflector CEX price data comes in two formats:

    OLD FORMAT (one price per row):
        key_decoded: {"u128":"32712048453743694797026099200011"}  -- last 2 digits = asset_index
        val_decoded: {"i128":"99994680135264"}                   -- the price

    NEW FORMAT (batch of prices per row):
        key_decoded: {"u64":"1773237600000"}
        val_decoded: {"map":[
            {"key":{"symbol":"mask"}, "val":{"bytes":"fffd00..."}},   -- bitmask: which assets have updated prices
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
            json_extract_scalar(storage_item, '$.key.symbol') as asset_code
            , cast(json_extract_scalar(storage_item, '$.val.u32') as int) as asset_index
        from {{ ref('contract_data_snapshot') }}
        , unnest(json_extract_array(val_decoded, '$.contract_instance.storage')) as storage_item
        where
            contract_id = 'CAFJZQWSED6YAWZU3GWRTOCNPPCGBN32L7QV43XX5LZLFTK6JLN34DLN'
            and contract_durability = 'ContractDataDurabilityPersistent'
            and json_extract_scalar(storage_item, '$.key.symbol') is not null
    )

    , price_data_old_format as (
        select
            closed_at
            , cast(right(json_extract_scalar(key_decoded, '$.u128'), 2) as int) as asset_index
            , cast(json_extract_scalar(val_decoded, '$.i128') as float64) as price
        from {{ ref('contract_data_snapshot') }}
        where
            contract_id = 'CAFJZQWSED6YAWZU3GWRTOCNPPCGBN32L7QV43XX5LZLFTK6JLN34DLN'
            and contract_durability != 'ContractDataDurabilityPersistent'
            and valid_to is null -- fetch only latest entry
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
            contract_id = 'CAFJZQWSED6YAWZU3GWRTOCNPPCGBN32L7QV43XX5LZLFTK6JLN34DLN'
            and contract_durability != 'ContractDataDurabilityPersistent'
            and valid_to is null
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
            asset_coding.asset_code
            , price_data.closed_at as updated_at
            , price_data.price * power(10, -14) as price
        from price_data
        left join asset_coding
            on price_data.asset_index = asset_coding.asset_index
    )

    -- Calculate daily OHLC prices from the raw price data
    , ohlc as (
        {{
            calc_ohlc(
                relation = 'joined',
                ts_col = 'updated_at',
                price_col = 'price',
                partition_cols = ['asset_code'],
            )
        }}
    )

select *
from ohlc
