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
                    order by ttl.closed_at
                ) as rn
        from {{ ref('stg_ttl') }} as ttl
        {% if is_incremental() %}
            -- limit the number of partitions fetched incrementally
            where
                ttl.closed_at >= timestamp_sub(current_timestamp(), interval 7 day)
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
