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

    -- A custom contract token that emits no SEP-41 events never appears in
    -- token_transfers_raw, so it would be missing from the asset registry altogether and
    -- every downstream join on it would drop the asset. Register those contracts from the
    -- balance-source seed so they exist here even with no event history.
    -- asset_code/asset_issuer stay null on purpose: the on-chain token symbol is not
    -- reliably unique (Tradable reuses one symbol across deals), so naming is left to the
    -- consuming project's recognized-asset list rather than guessed here.
    , eventless_contract_tokens as (
        select
            cast(null as string) as asset_code
            , cast(null as string) as asset_issuer
            , '' as asset_type
            , ctbs.contract_id as asset_contract_id
            , timestamp(ctbs.effective_from) as created_at
        from {{ ref('contract_token_balance_sources') }} as ctbs
        where ctbs.contract_id not in (
            select asset_contract_id
            from base_asset_list
            where asset_contract_id is not null
        )
    )

select * from base_asset_list
union all
select * from eventless_contract_tokens
