{{ 
    config(
        tags = ["current_state"],
        materialized = "incremental",
        unique_key = "account_id"
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
            , l.closed_at
            , a.deleted
            , a.sponsor
            , a.sequence_ledger
            , a.sequence_time
            , a.batch_run_date
            , a.batch_insert_ts
            , row_number()
            over (
                partition by a.account_id
                order by
                    a.last_modified_ledger desc
                    , a.ledger_entry_change desc
            )
            as row_nr
        from {{ ref('stg_accounts') }} as a
        join {{ ref('stg_history_ledgers') }} as l
            on a.last_modified_ledger = l.sequence

        {% if is_incremental() %}
            -- limit the number of partitions fetched
            where
                a.batch_run_date >= date_sub(current_date(), interval 30 day)
                -- fetch the last week of records loaded
                and timestamp_add(a.batch_insert_ts, interval 7 day)
                > (select max(t.upstream_insert_ts) from {{ this }} as t)
        {% endif %}
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
        left join account_date
            on current_accts.account_id = account_date.account_id
        where current_accts.row_nr = 1
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
    , batch_insert_ts as upstream_insert_ts
    , current_timestamp() as batch_insert_ts
from get_creation_account
