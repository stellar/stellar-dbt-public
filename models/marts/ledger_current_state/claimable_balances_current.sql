{{
    config(
        tags = ["current_state"],
        materialized = "incremental",
        unique_key = "balance_id"
    )
}}
/* Returns the latest state of each claimable balance in the `claimable_balances` table.

    Rank all rows for a claimable balance by closed_at timestamp and pick the latest one.*/

with
    current_balance as (
        select
            cb.balance_id
            , cb.claimants
            , cb.asset_type
            , cb.asset_code
            , cb.asset_issuer
            , cb.asset_amount
            , cb.sponsor
            , cb.flags
            , cb.last_modified_ledger
            , cb.ledger_entry_change
            , cb.deleted
            , cb.batch_id
            , cb.batch_run_date
            , cb.closed_at
            , cb.ledger_sequence
            , row_number()
                over (
                    partition by cb.balance_id
                    order by cb.closed_at desc
                ) as rn
        from {{ ref('stg_claimable_balances') }} as cb
        {% if is_incremental() %}
            -- limit the number of partitions fetched incrementally
            where
                cb.batch_run_date >= date_sub(date('{{ dbt_airflow_macros.ds() }}'), interval 2 day)
        {% endif %}
    )

select
    balance_id
    , claimants
    , asset_type
    , asset_code
    , asset_issuer
    , asset_amount
    , sponsor
    , flags
    , last_modified_ledger
    , ledger_entry_change
    , deleted
    , batch_id
    , batch_run_date
    , closed_at
    , ledger_sequence
from current_balance
where rn = 1
