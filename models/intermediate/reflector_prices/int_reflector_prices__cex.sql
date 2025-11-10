{{ config(
    materialized='table'
    )
}}

with asset_coding as (
    select distinct
        json_extract_scalar(storage_item, '$.key.symbol') as asset_code,
        cast(json_extract_scalar(storage_item, '$.val.u32') as int) as asset_index
    from {{ ref('contract_data_snapshot') }},
    unnest(json_extract_array(val_decoded, '$.contract_instance.storage')) as storage_item
    where contract_id = 'CAFJZQWSED6YAWZU3GWRTOCNPPCGBN32L7QV43XX5LZLFTK6JLN34DLN'
      and contract_durability = 'ContractDataDurabilityPersistent'
      and json_extract_scalar(storage_item, '$.key.symbol') is not null
),

price_data as (
    select
        closed_at,
        cast(right(json_extract_scalar(key_decoded, '$.u128'), 2) as int) as asset_index,
        cast(json_extract_scalar(val_decoded, '$.i128') as float64) as price
    from {{ ref('contract_data_snapshot') }}
    where contract_id = 'CAFJZQWSED6YAWZU3GWRTOCNPPCGBN32L7QV43XX5LZLFTK6JLN34DLN'
      and contract_durability != 'ContractDataDurabilityPersistent'
),

joined as (
    select
        asset_coding.asset_code,
        price_data.closed_at as updated_at,
        price_data.price * POWER (10, -14) as open_usd,
        price_data.price * POWER (10, -14) as high_usd,
        price_data.price * POWER (10, -14) as low_usd,
        price_data.price * POWER (10, -14) as close_usd
    from price_data
    left join asset_coding using (asset_index)
)

select *
from joined
