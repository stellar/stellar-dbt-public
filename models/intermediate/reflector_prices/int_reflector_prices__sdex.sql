{{ config(
    materialized='table'
    )
}}

with asset_coding as (
    select distinct
        json_extract_scalar(storage_item, '$.key.address') as asset_contract_id,
        cast(json_extract_scalar(storage_item, '$.val.u32') as int) as asset_index
    from {{ ref('contract_data_snapshot') }},
    unnest(json_extract_array(val_decoded, '$.contract_instance.storage')) as storage_item
    where contract_id = 'CALI2BYU2JE6WVRUFYTS6MSBNEHGJ35P4AVCZYF3B6QOE3QKOB2PLE6M'
      and contract_durability = 'ContractDataDurabilityPersistent'
      and json_extract_scalar(storage_item, '$.key.address') is not null
),

price_data as (
    select
        ledger_sequence,
        closed_at,
        cast(right(json_extract_scalar(key_decoded, '$.u128'), 2) as int) as asset_index,
        cast(json_extract_scalar(val_decoded, '$.i128') as float64) as price,
        json_extract_scalar(key_decoded, '$.u128') as key_name
    from {{ ref('contract_data_snapshot') }}
    where contract_id = 'CALI2BYU2JE6WVRUFYTS6MSBNEHGJ35P4AVCZYF3B6QOE3QKOB2PLE6M'
      and contract_durability != 'ContractDataDurabilityPersistent'
),

joined as (
    select
        price_data.key_name,
        price_data.ledger_sequence,
        price_data.closed_at,
        asset_coding.asset_contract_id,
        stg_assets.asset_code,
        stg_assets.asset_type,
        stg_assets.asset_issuer,
        asset_coding.asset_index,
        price_data.price
    from price_data
    left join asset_coding using (asset_index)
    left join {{ ref('stg_assets') }} stg_assets using (asset_contract_id)
)

select *
from joined
