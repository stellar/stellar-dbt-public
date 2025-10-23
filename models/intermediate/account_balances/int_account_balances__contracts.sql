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

-- Account balances for C addresses only
select
    d.day
    , tt.account_id
    , tt.asset_type
    , tt.asset_issuer
    , tt.asset_code
    , tt.contract_id
    , tt.balance
from {{ ref('int_account_balances__token_transfers') }} as tt
where
    true
    -- Only count C address balances
    and iabc.account_id like 'C%'
{% if is_incremental() %}
    and iabc.day >= date_sub(date('{{ dbt_airflow_macros.ts(timezone=none) }}'), interval 1 day)
{% endif %}
