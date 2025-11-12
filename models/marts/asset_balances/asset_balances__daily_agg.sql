{% set meta_config = {
    "materialized": "incremental",
    "incremental_strategy": "insert_overwrite",
    "unique_key": ["day", "contract_id"],
    "partition_by": {
         "field": "day"
        , "data_type": "date"
        , "granularity": "day"
    },
    "tags": ["asset_balance_agg"],
    "incremental_predicates": ["DBT_INTERNAL_DEST.day >= DATE_SUB(DATE('" ~ var('batch_start_date') ~ "'), INTERVAL 1 DAY)"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

with
    trustline_balance_changes as (
        select
            iabt.day
            , iabt.asset_code
            , iabt.asset_issuer
            , iabt.asset_type
            , iabt.contract_id
            , sum(iabt.balance) as total_balance
            , count(case when iabt.balance > 0 then 1 end) as total_accounts_with_balance
        from {{ ref('int_account_balances__trustlines') }} as iabt
        where
            true
            -- TODO: Remove nulls for now until contract_ids are added to stellar-etl.
            -- These assets would always have zero balance anyways so they have little impact
            and iabt.contract_id is not null
            -- Exclude XLM burn address
            and iabt.account_id != 'GALAXYVOIDAOPZTDLHILAJQKCVVFMD4IKLXLSZV5YHO7VY74IWZILUTO'
            and iabt.day < date('{{ var("batch_end_date") }}')
        {% if is_incremental() %}
            and iabt.day >= date('{{ var("batch_start_date") }}')
        {% endif %}
        group by 1, 2, 3, 4, 5
    )

    , liquidity_pools_balance_changes as (
        select
            iablp.day
            , iablp.asset_code
            , iablp.asset_issuer
            , iablp.asset_type
            , iablp.contract_id
            , sum(iablp.balance) as total_balance
            , count(case when iablp.balance > 0 then 1 end) as total_accounts_with_balance
        from {{ ref('int_account_balances__liquidity_pools') }} as iablp
        where
            true
            -- Exclude XLM burn address
            -- In theory there wouldn't be any XLM burn address LP but we can filter just in case
            and iablp.account_id != 'GALAXYVOIDAOPZTDLHILAJQKCVVFMD4IKLXLSZV5YHO7VY74IWZILUTO'
            and iablp.day < date('{{ var("batch_end_date") }}')
        {% if is_incremental() %}
            and iablp.day >= date('{{ var("batch_start_date") }}')
        {% endif %}
        group by 1, 2, 3, 4, 5
    )

    , offer_balance_changes as (
        select
            iabo.day
            , iabo.asset_code
            , iabo.asset_issuer
            , iabo.asset_type
            , iabo.contract_id
            , sum(iabo.balance) as total_balance
            , count(case when iabo.balance > 0 then 1 end) as total_accounts_with_balance
        from {{ ref('int_account_balances__offers') }} as iabo
        where
            true
            -- Exclude XLM burn address
            and iabo.account_id != 'GALAXYVOIDAOPZTDLHILAJQKCVVFMD4IKLXLSZV5YHO7VY74IWZILUTO'
            and iabo.day < date('{{ var("batch_end_date") }}')
        {% if is_incremental() %}
            and iabo.day >= date('{{ var("batch_start_date") }}')
        {% endif %}
        group by 1, 2, 3, 4, 5
    )

    , contract_balance_changes as (
        select
            iabc.day
            , iabc.asset_type
            , iabc.asset_code
            , iabc.asset_issuer
            , iabc.contract_id
            , sum(iabc.balance) as total_balance
            , count(case when iabc.balance > 0 then 1 end) as total_accounts_with_balance
        from {{ ref('int_account_balances__contracts') }} as iabc
        where
            true
            and iabc.day < date('{{ var("batch_end_date") }}')
        {% if is_incremental() %}
            and iabc.day >= date('{{ var("batch_start_date") }}')
        {% endif %}
        group by 1, 2, 3, 4, 5
    )

    , day_account_asset_pairs_all as (
        select
            tbc.day
            , tbc.asset_type
            , tbc.asset_code
            , tbc.asset_issuer
            , tbc.contract_id
        from trustline_balance_changes as tbc

        union all

        select
            lpbc.day
            , lpbc.asset_type
            , lpbc.asset_code
            , lpbc.asset_issuer
            , lpbc.contract_id
        from liquidity_pools_balance_changes as lpbc

        union all

        select
            obc.day
            , obc.asset_type
            , obc.asset_code
            , obc.asset_issuer
            , obc.contract_id
        from offer_balance_changes as obc

        union all

        select
            cbc.day
            , cbc.asset_type
            , cbc.asset_code
            , cbc.asset_issuer
            , cbc.contract_id
        from contract_balance_changes as cbc
    )

    , day_account_asset_pairs as (
        select distinct *
        from day_account_asset_pairs_all
    )

    , all_balances as (
        select
            daap.day
            , daap.asset_type
            , daap.asset_code
            , daap.asset_issuer
            , daap.contract_id
            , coalesce(lpbc.total_balance, 0) as liquidity_pool_balance
            , coalesce(obc.total_balance, 0) as offer_balance
            , coalesce(tbc.total_balance, 0) as trustline_balance
            , coalesce(cbc.total_balance, 0) as contract_balance
            , coalesce(lpbc.total_accounts_with_balance, 0) as total_accounts_with_liquidity_pool_balance
            , coalesce(obc.total_accounts_with_balance, 0) as total_accounts_with_offer_balance
            , coalesce(tbc.total_accounts_with_balance, 0) as total_accounts_with_trustline_balance
            , coalesce(cbc.total_accounts_with_balance, 0) as total_accounts_with_contract_balance

        from day_account_asset_pairs as daap

        left join liquidity_pools_balance_changes as lpbc
            on daap.contract_id = lpbc.contract_id
            and daap.day = lpbc.day

        left join offer_balance_changes as obc
            on daap.contract_id = obc.contract_id
            and daap.day = obc.day

        left join trustline_balance_changes as tbc
            on daap.contract_id = tbc.contract_id
            and daap.day = tbc.day

        left join contract_balance_changes as cbc
            on daap.contract_id = cbc.contract_id
            and daap.day = cbc.day
    )

select * from all_balances
where liquidity_pool_balance > 0 or offer_balance > 0 or trustline_balance > 0 or contract_balance > 0
