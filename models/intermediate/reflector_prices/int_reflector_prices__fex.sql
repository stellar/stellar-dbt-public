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
    Reflector FEX price data comes in two formats:

    OLD FORMAT (one price per row):
        key_decoded: {"u128":"32711755150512922815155404800013"}  -- last 2 digits = asset_index
        val_decoded: {"i128":"211875711480"}                     -- the price

    NEW FORMAT (batch of prices per row):
        key_decoded: {"u64":"1773334500000"}
        val_decoded: {"map":[
            {"key":{"symbol":"mask"}, "val":{"bytes":"ffffff00..."}},  -- bitmask: which assets have updated prices
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
            contract_id = 'CBKGPWGKSKZF52CFHMTRR23TBWTPMRDIYZ4O2P5VS65BMHYH4DXMCJZC'
            and contract_durability = 'ContractDataDurabilityPersistent'
            and json_extract_scalar(storage_item, '$.key.symbol') is not null
            and valid_to is null -- fetch only latest entry
    )

    , price_data_old_format as (
        select
            closed_at
            , cast(right(json_extract_scalar(key_decoded, '$.u128'), 2) as int) as asset_index
            , cast(json_extract_scalar(val_decoded, '$.i128') as float64) as price
        from {{ ref('contract_data_snapshot') }}
        where
            contract_id = 'CBKGPWGKSKZF52CFHMTRR23TBWTPMRDIYZ4O2P5VS65BMHYH4DXMCJZC'
            and contract_durability != 'ContractDataDurabilityPersistent'
            and json_extract_scalar(key_decoded, '$.u128') is not null
    )

    , new_format_raw as (
        select
            closed_at
            , json_extract_scalar(key_decoded, '$.u64') as key_value
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
            contract_id = 'CBKGPWGKSKZF52CFHMTRR23TBWTPMRDIYZ4O2P5VS65BMHYH4DXMCJZC'
            and contract_durability != 'ContractDataDurabilityPersistent'
            and json_extract_scalar(key_decoded, '$.u64') is not null
    )

    -- lookup table: hex character → integer value
    , hex_lookup as (
        select hex_char, int_val
        from unnest(['0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f']) as hex_char with offset as int_val
    )

    /*
        For each bit position (0–255), determine which hex nibble to read:
        - Bits 0-3 of a byte are in the LOW nibble (2nd hex char)
        - Bits 4-7 of a byte are in the HIGH nibble (1st hex char)
        Then shift right by (bit_pos % 4) and check if the lowest bit is set.
    */
    , new_format_mask_bits as (
        select
            r.closed_at
            , r.key_value
            , r.prices_array
            , bit_pos as asset_index
        from new_format_raw as r
        cross join unnest(generate_array(0, 255)) as bit_pos
        inner join hex_lookup as h
            on h.hex_char = substr(
                r.mask_hex
                -- byte position * 2, then pick low nibble (+2) for bits 0-3 or high nibble (+1) for bits 4-7
                , cast(floor(bit_pos / 8) as int64) * 2 + (case when mod(bit_pos, 8) < 4 then 2 else 1 end)
                , 1
            )
        where
            bit_pos < length(r.mask_hex) * 4
            and (h.int_val >> mod(bit_pos, 4)) & 1 = 1
    )

    -- the prices vec only has values for set bits, so map each asset_index to its vec position
    , new_format_indexed as (
        select
            closed_at
            , asset_index
            , prices_array
            , row_number() over (partition by closed_at, key_value order by asset_index) - 1 as vec_index
        from new_format_mask_bits
    )

    , price_data_new_format as (
        select
            closed_at
            , asset_index
            , cast(json_extract_scalar(prices_array[safe_offset(vec_index)], '$.i128') as float64) as price
        from new_format_indexed
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
