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

-- This int table computes the daily value movement for a given account_id NOT the daily balance.
-- account_id includes G, C, B, and L addresses.
-- The daily balance will be aggregated in int_account_balances__token_transfers.sql
-- TODO: account_ids should really be named addresses; This can be refactored in the future if needed
with
    dates as (
        {% if not is_incremental() %}
            select dates as day
            from unnest(generate_date_array('2015-09-30', date('{{ dbt_airflow_macros.ts(timezone=none) }}'))) as dates
        {% else %}
            select date('{{ dbt_airflow_macros.ts(timezone=none) }}') as day
        {% endif %}
    )

    -- Amounts should be added when assets are sent to the account
    , token_transfers_to as (
        select
            dt.day
            , tt.to as account_id
            , tt.contract_id
            , sum(tt.amount) as balance
        from dates as dt
        left join {{ ref('stg_token_transfers_raw') }} as tt
            on date(tt.closed_at) = dt.day
        where
            true
            and tt.to is not null
        group by 1, 2, 3
    )

    -- Amounts should be subtracted when assets are sent from the account
    , token_transfers_from as (
        select
            dt.day
            , tt.from as account_id
            , tt.contract_id
            , -sum(tt.amount) as balance
        from dates as dt
        left join {{ ref('stg_token_transfers_raw') }} as tt
            on date(tt.closed_at) = dt.day
        where
            true
            and tt.from is not null
        group by 1, 2, 3
    )

    , merge_results as (
        select * from token_transfers_to
        union all
        select * from token_transfers_from
    )

select
    day
    , account_id
    , contract_id
    -- Final balance = sum(transfer + mint amounts to account) - sum(transfer + burn + clawback amounts from account) as balance
    , sum(balance) as balance
from merge_results
group by 1, 2, 3
