{% set meta_config = {
    "tags": ["assets"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

with
    asset_per_contract as (
        -- stg_assets.asset_contract_id is unique (see stg_assets.yml), so no aggregation needed.
        select
            asset_contract_id as contract_id
            , nullif(asset_code, '') as asset_code
            , nullif(asset_issuer, '') as asset_issuer
            , nullif(asset_type, '') as asset_type
        from {{ ref('stg_assets') }}
        where asset_contract_id is not null
    )

    -- SEP-41 / SAC metadata read directly from contract storage.
    , unique_contracts as (
        select distinct contract_id
        from {{ ref('stg_token_transfers_raw') }}
        -- filter only for soroban contracts
        where closed_at >= '2024-02-01'
    )

    , contract_metadata as (
        select
            uc.contract_id
            , cd.val_decoded
        from unique_contracts as uc
        left join {{ ref('contract_data_current') }} as cd
            on uc.contract_id = cd.contract_id
        where cd.contract_key_type = 'ScValTypeScvLedgerKeyContractInstance'
    )

    , flattened_data as (
        select
            contract_id
            , json_value(m.key.symbol) as metadata_key
            , json_value(s.key.vec[0].symbol) as admin_key
            , json_value(m.val.string) as val_string
            , json_value(m.val.u32) as val_u32
            , json_value(s.val.address) as admin_address
        from contract_metadata
        -- First unnest the storage array
        , unnest(json_query_array(val_decoded.contract_instance.storage)) as s
        -- left join unnest the map array (since Admin doesn't have a map, it would be filtered out otherwise)
        left join unnest(json_query_array(s.val.map)) as m
    )

    , metadata as (
        select
            contract_id
            -- Extract Admin (from the storage level)
            , max(if(admin_key = 'Admin', admin_address, null)) as `admin`
            -- Extract Metadata (from the map level)
            , max(if(metadata_key = 'symbol', val_string, null)) as `symbol`
            , max(if(metadata_key = 'name', val_string, null)) as `name`
            , max(if(metadata_key in ('decimal', 'decimals'), val_u32, null)) as `decimal`
        from flattened_data
        group by contract_id
    )

    , all_contracts as (
        select contract_id from asset_per_contract
        union distinct
        select contract_id from metadata
    )

    -- SAC rows carry no contract-storage metadata of their own, so `decimal` is null on
    -- the SAC row. When a SAC and a SEP-41 contract share the same asset_code AND the
    -- SAC's asset_issuer matches the SEP-41's admin, we treat the SEP-41 as the SAC's
    -- sibling and let the SAC inherit the SEP-41's decimals. This avoids the failure
    -- mode where a SAC of an 18-decimal SEP-41 token gets scaled at the default 10^-7
    -- in downstream amount calculations. The issuer/admin guard prevents cross-linking
    -- unrelated tokens that happen to share an asset_code.
    , sac_sibling_decimals as (
        select
            a.contract_id as sac_contract_id
            , m.`decimal` as sibling_decimal
        from asset_per_contract as a
        inner join metadata as m
            on a.asset_code = m.symbol
            and a.asset_issuer = m.admin
        where m.`decimal` is not null
        qualify row_number() over (
            partition by a.contract_id
            order by safe_cast(m.`decimal` as int64) desc
        ) = 1
    )

select
    c.contract_id
    -- Resolves to the SAC asset_code from token-transfer events, falling back to the SEP-41
    -- symbol read from contract storage. Returns null when neither is available — downstream
    -- consumers must handle null asset_code for contract tokens that publish no metadata.
    , coalesce(a.asset_code, m.symbol) as asset_code
    , a.asset_issuer
    , a.asset_type
    , m.symbol
    , m.`name`
    , coalesce(m.`decimal`, s.sibling_decimal) as `decimal`
    , m.admin
    , case
        when a.asset_code is not null then 'sac'
        when m.symbol is not null then 'metadata'
    end as asset_code_source
from all_contracts as c
left join asset_per_contract as a
    on c.contract_id = a.contract_id
left join metadata as m
    on c.contract_id = m.contract_id
left join sac_sibling_decimals as s
    on c.contract_id = s.sac_contract_id
