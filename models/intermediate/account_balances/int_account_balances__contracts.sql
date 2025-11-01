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
-- This table doesn't do any transformations/filtering because int_account_balances__token_transfers currently only contains C addresses
select
    tt.day
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
    and tt.account_id like 'C%'
    and tt.day < date('{{ var("batch_end_date") }}')
{% if is_incremental() %}
    and tt.day >= date('{{ var("batch_start_date") }}')
{% endif %}
