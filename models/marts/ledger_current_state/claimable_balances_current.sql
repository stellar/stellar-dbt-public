{% set meta_config = {
    "materialized": "incremental",
    "unique_key": "balance_id",
    "tags": ["current_state"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
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
        from {{ ref('stg_claimable_balances') }} as cb
        where
            true
            -- Need to add/subtract one day to the window boundaries
            -- because this model runs at 30 min increments.
            -- Without the additional date buffering the following would occur
            -- * batch_start_date == '2025-01-01 01:00:00' --> '2025-01-01'
            -- * batch_end_date == '2025-01-01 01:30:00' --> '2025-01-01'
            -- * '2025-01-01 <= closed_at < '2025-01-01' would never have any data to processes
            and cb.batch_run_date < datetime(date_add(date('{{ var("batch_end_date") }}'), interval 1 day))
        {% if is_incremental() %}
            -- The extra day date_sub is useful in the case the first scheduled run for a day is skipped
            -- because the DAG is configured with catchup=false
            and cb.batch_run_date >= datetime(date_sub(date('{{ var("batch_start_date") }}'), interval 1 day))
    {% endif %}
        qualify row_number()
            over (
                partition by cb.balance_id
                order by cb.closed_at desc
            )
        = 1
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
    , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
from current_balance
