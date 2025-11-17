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

    , price_data as (
        select
            closed_at
            , cast(right(json_extract_scalar(key_decoded, '$.u128'), 2) as int) as asset_index
            , cast(json_extract_scalar(val_decoded, '$.i128') as float64) as price
        from {{ ref('contract_data_snapshot') }}
        where
            contract_id = 'CBKGPWGKSKZF52CFHMTRR23TBWTPMRDIYZ4O2P5VS65BMHYH4DXMCJZC'
            and contract_durability != 'ContractDataDurabilityPersistent'
    )

    , joined as (
        select
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
