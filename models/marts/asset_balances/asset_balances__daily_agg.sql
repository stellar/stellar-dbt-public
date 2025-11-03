{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["day", "asset_type", "asset_code", "asset_issuer"],
    "partition_by": {
         "field": "day"
        , "data_type": "date"
        , "granularity": "day"
    },
    "tags": ["asset_balance_agg"],
    "incremental_predicates": ["DBT_INTERNAL_DEST.day >= DATE_SUB(DATE('" ~ var('execution_date') ~ "'), INTERVAL 1 DAY)"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

with
    trustline_balance_changes as (
        select
            iabc.day
            , iabc.asset_code
            , iabc.asset_issuer
            , iabc.asset_type
            , sum(iabc.balance) as total_balance
            , count(account_id) as total_accounts_with_trustline
            , count(case when iabc.balance > 0 then 1 end) as total_accounts_with_balance
        from {{ ref('int_account_balances__trustlines') }} as iabc
        {% if is_incremental() %}
            where iabc.day >= date_sub(date('{{ dbt_airflow_macros.ts(timezone=none) }}'), interval 1 day)
        {% endif %}
        group by 1, 2, 3, 4
    )

    , liquidity_pools_balance_changes as (
        select
            iablp.day
            , iablp.asset_code
            , iablp.asset_issuer
            , iablp.asset_type
            , sum(iablp.balance) as total_balance
            , count(case when iablp.balance > 0 then 1 end) as total_accounts_with_balance
        from {{ ref('int_account_balances__liquidity_pools') }} as iablp
        {% if is_incremental() %}
            where iablp.day >= date_sub(date('{{ dbt_airflow_macros.ts(timezone=none) }}'), interval 1 day)
        {% endif %}
        group by 1, 2, 3, 4
    )

    , offer_balance_changes as (
        select
            iabo.day
            , iabo.asset_code
            , iabo.asset_issuer
            , iabo.asset_type
            , sum(iabo.balance) as total_balance
            , count(case when iabo.balance > 0 then 1 end) as total_accounts_with_balance
        from {{ ref('int_account_balances__offers') }} as iabo
        {% if is_incremental() %}
            where iabo.day >= date_sub(date('{{ dbt_airflow_macros.ts(timezone=none) }}'), interval 1 day)
        {% endif %}
        group by 1, 2, 3, 4
    )

    , day_account_asset_pairs as (
        select distinct * from (
            select
                tbc.day
                , tbc.asset_type
                , tbc.asset_code
                , tbc.asset_issuer
            from trustline_balance_changes as tbc

            union all

            select
                lpbc.day
                , lpbc.asset_type
                , lpbc.asset_code
                , lpbc.asset_issuer
            from liquidity_pools_balance_changes as lpbc

            union all

            select
                obc.day
                , obc.asset_type
                , obc.asset_code
                , obc.asset_issuer
            from offer_balance_changes as obc
        )
    )

    , all_balances as (
        select
            daap.day
            , daap.asset_type
            , daap.asset_code
            , daap.asset_issuer
            , coalesce(lpbc.total_balance, 0) as liquidity_pool_balance
            , coalesce(obc.total_balance, 0) as offer_balance
            , coalesce(tbc.total_balance, 0) as trustline_balance
            , coalesce(lpbc.total_accounts_with_balance, 0) as total_accounts_with_liquidity_pool_balance
            , coalesce(obc.total_accounts_with_balance, 0) as total_accounts_with_offer_balance
            , coalesce(tbc.total_accounts_with_balance, 0) as total_accounts_with_trustline_balance
            , coalesce(tbc.total_accounts_with_trustline) as total_accounts_with_trustline

        from day_account_asset_pairs as daap

        left join liquidity_pools_balance_changes as lpbc
            on daap.asset_type = lpbc.asset_type
            and daap.asset_code = lpbc.asset_code
            and daap.asset_issuer = lpbc.asset_issuer
            and daap.day = lpbc.day

        left join offer_balance_changes as obc
            on daap.asset_type = obc.asset_type
            and daap.asset_code = obc.asset_code
            and daap.asset_issuer = obc.asset_issuer
            and daap.day = obc.day

        left join trustline_balance_changes as tbc
            on daap.asset_type = tbc.asset_type
            and daap.asset_code = tbc.asset_code
            and daap.asset_issuer = tbc.asset_issuer
            and daap.day = tbc.day
        order by 1, 2, 3, 4
    )
select * from all_balances
where liquidity_pool_balance > 0 or offer_balance > 0 or trustline_balance > 0
