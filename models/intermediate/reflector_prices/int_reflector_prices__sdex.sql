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
            contract_id = 'CALI2BYU2JE6WVRUFYTS6MSBNEHGJ35P4AVCZYF3B6QOE3QKOB2PLE6M'
            and contract_durability != 'ContractDataDurabilityPersistent'
            and json_extract_scalar(key_decoded, '$.u64') is not null
    )

    -- expand mask hex into set bit positions (each set bit = an asset_index with a price)
    , new_format_mask_bits as (
        select
            closed_at
            , key_value
            , prices_array
            , bit_pos as asset_index
        from new_format_raw
        cross join unnest(generate_array(0, 255)) as bit_pos
        where
            bit_pos < length(mask_hex) * 4
            and ((
                case substr(
                    mask_hex
                    , cast(floor(bit_pos / 8) as int64) * 2 + (case when mod(bit_pos, 8) < 4 then 2 else 1 end)
                    , 1
                )
                    when '0' then 0 when '1' then 1 when '2' then 2 when '3' then 3
                    when '4' then 4 when '5' then 5 when '6' then 6 when '7' then 7
                    when '8' then 8 when '9' then 9 when 'a' then 10 when 'b' then 11
                    when 'c' then 12 when 'd' then 13 when 'e' then 14 when 'f' then 15
                end
            ) >> mod(bit_pos, 4)) & 1 = 1
    )

    -- map each set bit to its position in the prices vec
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
