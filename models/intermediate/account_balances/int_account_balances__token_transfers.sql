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
-- Note that account_id currently only includes C addresses because int_account_balances__token_transfers_value_movement
-- currently only includes C addresses
with
{% if is_incremental() %}
        -- Create a union of previous balances and new value movements for incremental runs
        -- so we don't have to aggregate the entire history again
        previous_balances as (
            select
                day
                , account_id
                , contract_id
                , balance
            from {{ this }}
            where true
                -- Get the latest balance from before the incremental run date
                and day <= date_sub(date('{{ dbt_airflow_macros.ts(timezone=none) }}'), interval 1 day)
            qualify row_number() over (
                partition by account_id, contract_id
                order by day desc
            ) = 1
        ),

        value_movements as (
            select
                day
                , account_id
                , contract_id
                , balance
            from {{ ref('int_account_balances__token_transfers_value_movement') }}
            where true
                -- Get the value movements since the last balance date
                and day > (select max(day) from previous_balances)
                and day <= date('{{ dbt_airflow_macros.ts(timezone=none) }}')
        ),

        merged_value_movements as (
            select * from previous_balances
            union all
            select * from value_movements
        ),
    {% endif %}

    account_date_ranges as (
        select
            account_id
            , contract_id
            , min(day) as start_day
            , max(day) as last_change_day
        {% if is_incremental() %}
                from merged_value_movements
            {% else %}
            from {{ ref('int_account_balances__token_transfers_value_movement') }}
        {% endif %}
        where
            true
            and day <= date('{{ dbt_airflow_macros.ts(timezone=none) }}')
        group by 1, 2
    )

    , date_spine as (
        select
            adr.account_id
            , adr.contract_id
            , day
        from account_date_ranges as adr
        , unnest(generate_date_array(adr.start_day, date('{{ dbt_airflow_macros.ts(timezone=none) }}'))) as day
    )

    , cumulative as (
        select
            day
            , account_id
            , contract_id
            , sum(balance) over (
                partition by account_id, contract_id
                order by day
                rows between unbounded preceding and current row
            ) as balance_on_day
        {% if is_incremental() %}
                from merged_value_movements
            {% else %}
            from {{ ref('int_account_balances__token_transfers_value_movement') }}
        {% endif %}
        where
            true
            and day <= date('{{ dbt_airflow_macros.ts(timezone=none) }}')
    )

    , daily_balances as (
        select
            ds.day
            , ds.account_id
            , ds.contract_id
            , last_value(c.balance_on_day ignore nulls) over (
                partition by ds.account_id, ds.contract_id
                order by ds.day
                rows between unbounded preceding and current row
            ) as balance
        from date_spine as ds
        left join cumulative as c
            on ds.account_id = c.account_id
            and ds.contract_id = c.contract_id
            and ds.day = c.day
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
