{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["day", "account_id", "contract_id"],
    "partition_by": {
         "field": "day"
        , "data_type": "date"
        , "granularity": "day"
    },
    "cluster_by": ["account_id", "contract_id"],
    "incremental_predicates": ["DBT_INTERNAL_DEST.day >= DATE_SUB(DATE('" ~ var('execution_date') ~ "'), INTERVAL 1 DAY)"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

-- This table computes the daily balance for a given account_id
with
    dates as (
        {% if not is_incremental() %}
            select dates as day
            from unnest(generate_date_array('2023-01-01', date('{{ dbt_airflow_macros.ts(timezone=none) }}'))) as dates
        {% else %}
            select date('{{ dbt_airflow_macros.ts(timezone=none) }}') as day
        {% endif %}
    )

    , daily_balances as (
        select
            d.day
            , ttvm.account_id
            , ttvm.contract_id
            , sum(ttvm.balance) as balance
        from dates as d
        left join {{ ref('int_account_balances__token_transfers_value_movement') }} as ttvm
            on d.day >= ttvm.day
        group by 1, 2, 3
    )

select
    db.day
    , db.account_id
    , db.contract_id
    , a.asset_type
    , a.asset_issuer
    , a.asset_code
    , db.balance
from daily_balances as db
left join {{ ref('int_assets') }} as a
    on db.contract_id = a.contract_id
