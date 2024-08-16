{{
    config(
        tags = ["current_state"],
        materialized = "incremental",
        unique_key = "unique_id",
        cluster_by = "account_id"
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
            , l.closed_at
            , s.ledger_entry_change
            , s.deleted
            -- table only has natural keys, creating a primary key
            , concat(s.account_id, '-', s.signer
            ) as unique_id
            , s.batch_run_date
            , row_number()
                over (
                    partition by s.account_id, s.signer
                    order by s.last_modified_ledger desc, s.ledger_entry_change desc
                ) as row_nr
        from {{ ref('stg_account_signers') }} as s
        join {{ ref('stg_history_ledgers') }} as l
            on s.last_modified_ledger = l.sequence

        {% if is_incremental() %}
            -- limit the number of partitions fetched
            where
                s.batch_run_date >= date_sub(current_date(), interval 30 day)
                -- fetch the last week of records loaded
                and timestamp_add(s.batch_insert_ts, interval 7 day)
                > (select max(t.upstream_insert_ts) from {{ this }} as t)
        {% endif %}
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
from current_signers
where row_nr = 1
