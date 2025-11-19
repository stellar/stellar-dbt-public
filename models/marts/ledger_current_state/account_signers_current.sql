{% set meta_config = {
    "materialized": "incremental",
    "unique_key": "unique_id",
    "cluster_by": "account_id",
    "tags": ["current_state"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

/* Finds the latest state of each account signer in the `account_signers` table.
   Ranks each record (grain: one row per account) using
   last modified ledger sequence number. View includes all account signers.
   (Deleted and Existing). View matches the Horizon snapshotted state tables. */
with
    current_signers as (
        select
            s.account_id
            , s.signer
            , s.weight
            , s.sponsor
            , s.last_modified_ledger
            , s.closed_at
            , s.ledger_entry_change
            , s.deleted
            -- table only has natural keys, creating a primary key
            , concat(s.account_id, '-', s.signer
            ) as unique_id
            , s.batch_run_date
        from {{ ref('stg_account_signers') }} as s
        where
            true
            -- Need to add/subtract one day to the window boundaries
            -- because this model runs at 30 min increments.
            -- Without the additional date buffering the following would occur
            -- * batch_start_date == '2025-01-01 01:00:00' --> '2025-01-01'
            -- * batch_end_date == '2025-01-01 01:30:00' --> '2025-01-01'
            -- * '2025-01-01 <= closed_at < '2025-01-01' would never have any data to processes
            and s.batch_run_date < datetime(date_add(date('{{ var("batch_end_date") }}'), interval 1 day))
        {% if is_incremental() %}
            -- The extra day date_sub is useful in the case the first scheduled run for a day is skipped
            -- because the DAG is configured with catchup=false
            and s.batch_run_date >= datetime(date_sub(date('{{ var("batch_start_date") }}'), interval 1 day))
    {% endif %}
        qualify row_number()
            over (
                partition by s.account_id, s.signer
                order by s.closed_at desc
            )
        = 1
    )
select
    account_id
    , signer
    , weight
    , sponsor
    , last_modified_ledger
    , ledger_entry_change
    , closed_at
    , deleted
    , unique_id
    , batch_run_date
    , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
from current_signers
