with
    base_asset_list as (
        select
            case when asset_type = 'native' then 'XLM' else asset_code end as asset_code
            , case when asset_type = 'native' then 'XLM' else asset_issuer end as asset_issuer
            , asset_type
            , contract_id as asset_contract_id
            , min(closed_at) as created_at
        from {{ ref('stg_token_transfers_raw') }}
        group by 1, 2, 3, 4
    )

select *
from base_asset_list
union all
-- support downstream models that expect native asset to have empty code and issuer
select
    '' as asset_code
    , '' as asset_issuer
    , asset_type
    , asset_contract_id
    , created_at
from base_asset_list
where asset_type = 'native'
