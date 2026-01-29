{% set meta_config = {
    "unique_key": ["contract_id"],
    "tags": ["assets"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

with
    token_transfers as (
        select contract_id
        from {{ ref('stg_token_transfers_raw') }}
        where closed_at >= '2024-02-01'
    ), unique_contracts as (
        select distinct contract_id 
        from token_transfers
    ), contract_metadata as (
        select
            uc.contract_id
            , cd.val_decoded
        from unique_contracts as uc
        left join {{ ref('contract_data_current') }} as cd
            on uc.contract_id = cd.contract_id
        where cd.contract_key_type = 'ScValTypeScvLedgerKeyContractInstance'
    ), flattened_data as (
        select
            contract_id
            , json_value(s.key.symbol) as storage_key
            , json_value(m.key.symbol) as metadata_key
            , json_value(m.val.string) as val_string
            , json_value(m.val.u32) as val_u32
            , json_value(s.val.address) as admin_address
        from contract_metadata
        -- First unnest the storage array
        , unnest(json_query_array(val_decoded.contract_instance.storage)) as s
        -- left join unnest the map array (since Admin doesn't have a map, it would be filtered out otherwise)
        left join unnest(json_query_array(s.val.map)) as m
    )
select
    contract_id
    -- Extract Admin (from the storage level)
    , max(if(storage_key is null and admin_address is not null, admin_address, null)) as `admin`
    -- Extract Metadata (from the map level)
    , max(if(metadata_key = 'symbol', val_string, null)) as `symbol`
    , max(if(metadata_key = 'name', val_string, null)) as `name`
    , max(if(metadata_key = 'decimal', val_u32, null)) as `decimal`
from flattened_data
group by contract_id