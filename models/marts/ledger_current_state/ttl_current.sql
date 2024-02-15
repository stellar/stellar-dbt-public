{{ config(
    tags = ["current_state"]
    , materialized='incremental'
    , unique_key=["key_hash"]
    , cluster_by= ["key_hash"]
    )
}}

/* Finds the latest state of each ttl for contracts or wasms.
   Ranks each record (grain: one row per contract_id/contract_code_hash)) using
   the last modified ledger sequence number. */

with
    current_expiration as (
        select
            ttl.key_hash
            , ttl.live_until_ledger_seq
            , ttl.last_modified_ledger
            , ttl.ledger_entry_change
            , ttl.closed_at
            , ttl.deleted
            , ttl.batch_id
            , ttl.batch_run_date
            , ttl.batch_insert_ts
            , row_number()
                over (
                    partition by ttl.key_hash
                    order by ttl.last_modified_ledger desc, ledger_entry_change
                ) as rn
        from {{ ref('stg_ttl') }} as ttl
        {% if is_incremental() %}
            -- limit the number of partitions fetched incrementally
            where
                ttl.batch_run_date >= date_sub(current_date(), interval 30 day)
                -- fetch the last week of records loaded
                and timestamp_add(ttl.batch_insert_ts, interval 7 day)
                > (select max(t.upstream_insert_ts) from {{ this }} as t)
        {% endif %}
    )

select
    key_hash
    , live_until_ledger_seq
    , last_modified_ledger
    , ledger_entry_change
    , closed_at
    , deleted
    , batch_id
    , batch_run_date
    , batch_insert_ts as upstream_insert_ts
    , current_timestamp() as batch_insert_ts
from current_expiration
where rn = 1
