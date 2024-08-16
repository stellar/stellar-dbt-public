{{ config(
    tags = ["current_state"]
    , materialized='incremental'
    , unique_key=["contract_code_hash"]
    , cluster_by= ["contract_code_hash"]
    )
}}

/* Finds the latest state of each contract code entry.
   Ranks each record (grain: one row per contract_code_hash)) using
   the last modified ledger sequence number. */

with
    current_code as (
        select
            cc.contract_code_hash
            , cc.contract_code_ext_v
            , cc.last_modified_ledger
            , cc.ledger_entry_change
            , cc.closed_at
            , cc.deleted
            , cc.batch_id
            , cc.batch_run_date
            , cc.ledger_sequence
            , cc.ledger_key_hash
            , row_number()
                over (
                    partition by cc.contract_code_hash
                    order by cc.closed_at desc
                ) as rn
        from {{ ref('stg_contract_code') }} as cc
        {% if is_incremental() %}
            -- limit the number of partitions fetched incrementally
            where
                cc.closed_at >= timestamp_sub(current_timestamp(), interval 30 day)
                -- fetch the last week of records loaded
                and timestamp_add(cc.batch_insert_ts, interval 7 day)
                > (select max(t.upstream_insert_ts) from {{ this }} as t)
        {% endif %}
    )

select
    contract_code_hash
    , contract_code_ext_v
    , last_modified_ledger
    , ledger_entry_change
    , ledger_sequence
    , ledger_key_hash
    , closed_at
    , deleted
    , batch_id
    , batch_run_date
from current_code
where rn = 1
