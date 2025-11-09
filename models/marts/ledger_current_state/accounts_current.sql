{% set meta_config = {
    "materialized": "incremental",
    "unique_key": "account_id",
    "tags": ["current_state"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

/* Returns the latest state of each account in the `accounts` table.
   Table includes all accounts. (Deleted and Existing).

    Rank all rows for an account by last modified ledger and ledger entry type.
    Deleted entry types reuse the last modified ledger sequence */

with
    current_accts as (
        select
            a.account_id
            , a.balance
            , a.buying_liabilities
            , a.selling_liabilities
            , a.sequence_number
            , a.num_subentries
            , a.num_sponsoring
            , a.num_sponsored
            , a.inflation_destination
            , a.flags
            , a.home_domain
            , a.master_weight
            , a.threshold_low
            , a.threshold_medium
            , a.threshold_high
            , a.last_modified_ledger
            , a.ledger_entry_change
            , a.closed_at
            , a.deleted
            , a.sponsor
            , a.sequence_ledger
            , a.sequence_time
            , a.batch_run_date
        from {{ ref('stg_accounts') }} as a
        where
            true
            -- Need to add/subtract one day to the window boundaries
            -- because this model runs at 30 min increments.
            -- Without the additional date buffering the following would occur
            -- * batch_start_date == '2025-01-01 01:00:00' --> '2025-01-01'
            -- * batch_end_date == '2025-01-01 01:30:00' --> '2025-01-01'
            -- * '2025-01-01 <= batch_run_date < '2025-01-01' would never have any data to processes
            -- TODO: change batch_run_date to closed_at once the table is repartitioned on closed_at
            and batch_run_date < datetime(date_add(date('{{ var("batch_end_date") }}'), interval 1 day))
        {% if is_incremental() %}
            -- The extra day date_sub is useful in the case the first scheduled run for a day is skipped
            -- because the DAG is configured with catchup=false
            and batch_run_date >= datetime(date_sub(date('{{ var("batch_start_date") }}'), interval 1 day))
    {% endif %}
        qualify row_number()
            over (
                partition by a.account_id
                order by
                    a.last_modified_ledger desc
                    , a.ledger_entry_change desc
            )
        = 1
    )

    , account_date as (
        select
            account_id
            , min(batch_run_date) as account_creation_date
            , min(sequence_number) as min_sequence_number
        from {{ ref('stg_accounts') }}
        group by account_id
    )

    , get_creation_account as (
        select
            current_accts.*
            , account_date.account_creation_date
            , account_date.min_sequence_number
        from current_accts
        join account_date
            on current_accts.account_id = account_date.account_id
    )

/* Return the same fields as the `accounts` table */
select
    account_id
    , account_creation_date
    , min_sequence_number
    , balance
    , buying_liabilities
    , selling_liabilities
    , sequence_number
    , num_subentries
    , num_sponsoring
    , num_sponsored
    , inflation_destination
    , flags
    , home_domain
    , master_weight
    , threshold_low
    , threshold_medium
    , threshold_high
    , last_modified_ledger
    , ledger_entry_change
    , closed_at
    , deleted
    , sponsor
    , sequence_ledger
    , sequence_time
    , batch_run_date
    , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
from get_creation_account
