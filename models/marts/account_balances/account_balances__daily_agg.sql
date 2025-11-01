{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["day", "account_id", "contract_id"],
    "partition_by": {
         "field": "day"
        , "data_type": "date"
        , "granularity": "day"
    },
    "cluster_by": ["account_id", "contract_id"],
    "tags": ["asset_balance_agg", "account_balance_agg"],
    "incremental_predicates": ["DBT_INTERNAL_DEST.day >= DATE_SUB(DATE('" ~ var('execution_date') ~ "'), INTERVAL 1 DAY)"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

-- Note that this model is also tagged with asset_balance_agg because it shares the same upstream dependencies.
-- The tag asset_balance_agg will be used in airflow to run this model and its upstream dependencies.
with
    trustline_balance_changes as (
        select
            iabt.day
            , iabt.account_id
            , iabt.asset_code
            , iabt.asset_issuer
            , iabt.asset_type
            , iabt.contract_id
            , iabt.balance as total_balance
        from {{ ref('int_account_balances__trustlines') }} as iabt
        where
            true
            and iabt.balance > 0
            and iabt.day < date('{{ var("batch_end_date") }}')
        {% if is_incremental() %}
            and iabt.day >= date('{{ var("batch_start_date") }}')
        {% endif %}
    )

    , liquidity_pools_balance_changes as (
        select
            iablp.day
            , iablp.account_id
            , iablp.asset_code
            , iablp.asset_issuer
            , iablp.asset_type
            , iablp.contract_id
            , iablp.balance as total_balance
        from {{ ref('int_account_balances__liquidity_pools') }} as iablp
        where
            true
            and iablp.balance > 0
            and iablp.day < date('{{ var("batch_end_date") }}')
        {% if is_incremental() %}
            and iablp.day >= date('{{ var("batch_start_date") }}')
        {% endif %}
    )

    , offer_balance_changes as (
        select
            iabo.day
            , iabo.account_id
            , iabo.asset_code
            , iabo.asset_issuer
            , iabo.asset_type
            , iabo.contract_id
            , iabo.balance as total_balance
        from {{ ref('int_account_balances__offers') }} as iabo
        where
            true
            and iabo.balance > 0
            and iabo.day < date('{{ var("batch_end_date") }}')
        {% if is_incremental() %}
            and iabo.day >= date('{{ var("batch_start_date") }}')
        {% endif %}
    )

    , contract_balance_changes as (
        select
            iabc.day
            , iabc.account_id
            , iabc.asset_type
            , iabc.asset_code
            , iabc.asset_issuer
            , iabc.contract_id
            , iabc.balance as total_balance
        from {{ ref('int_account_balances__contracts') }} as iabc
        where
            true
            and iabc.balance > 0
            and iabc.day < date('{{ var("batch_end_date") }}')
        {% if is_incremental() %}
            and iabc.day >= date('{{ var("batch_start_date") }}')
        {% endif %}
    )

    , day_account_asset_pairs_all as (
        select
            tbc.day
            , tbc.account_id
            , tbc.asset_type
            , tbc.asset_code
            , tbc.asset_issuer
            , tbc.contract_id
        from trustline_balance_changes as tbc

        union all

        select
            lpbc.day
            , lpbc.account_id
            , lpbc.asset_type
            , lpbc.asset_code
            , lpbc.asset_issuer
            , lpbc.contract_id
        from liquidity_pools_balance_changes as lpbc

        union all

        select
            obc.day
            , obc.account_id
            , obc.asset_type
            , obc.asset_code
            , obc.asset_issuer
            , obc.contract_id
        from offer_balance_changes as obc

        union all

        select
            cbc.day
            , cbc.account_id
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
            , daap.account_id
            , daap.asset_type
            , daap.asset_code
            , daap.asset_issuer
            , daap.contract_id
            , coalesce(lpbc.total_balance, 0) as liquidity_pool_balance
            , coalesce(obc.total_balance, 0) as offer_balance
            , coalesce(tbc.total_balance, 0) as trustline_balance
            , coalesce(cbc.total_balance, 0) as contract_balance

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

-- Filter out rows where all balances are zero
select * from all_balances
where liquidity_pool_balance > 0 or offer_balance > 0 or trustline_balance > 0 or contract_balance > 0
