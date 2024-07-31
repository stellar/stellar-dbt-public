{{ config(
    tags = ["current_state"]
    , materialized='incremental'
    , unique_key=["unique_id"]
    , cluster_by= ["contract_id"]
    )
}}

/* Finds the latest state of each contract data entry.
   Ranks each record (grain: one row per contract_id + ledger_key_hash)) using
   the last modified ledger sequence number. */

with
    current_data as (
        select
            cd.contract_id
            , cd.contract_key_type
            , cd.contract_durability
            , cd.asset_code
            , cd.asset_issuer
            , cd.asset_type
            , cd.balance_holder
            , cd.balance
            , cd.last_modified_ledger
            , cd.ledger_entry_change
            , cd.closed_at
            , cd.deleted
            , cd.batch_id
            , cd.batch_run_date
            , cd.batch_insert_ts
            , cd.ledger_sequence
            , cd.ledger_key_hash
            , concat(cd.contract_id, '-', cd.ledger_key_hash) as unique_id
            , row_number()
                over (
                    partition by cd.contract_id, cd.ledger_key_hash
                    order by cd.closed_at desc
                ) as rn
        from {{ ref('stg_contract_data') }} as cd
        {% if is_incremental() %}
            -- limit the number of partitions fetched incrementally
            where
                cd.closed_at >= timestamp_sub(current_timestamp(), interval 30 day)
                -- fetch the last week of records loaded
                and timestamp_add(cd.batch_insert_ts, interval 7 day)
                > (select max(t.upstream_insert_ts) from {{ this }} as t)
        {% endif %}
    )

select
    contract_id
    , contract_key_type
    , contract_durability
    , asset_code
    , asset_issuer
    , asset_type
    , balance_holder
    , balance
    , last_modified_ledger
    , ledger_entry_change
    , ledger_sequence
    , ledger_key_hash
    , closed_at
    , deleted
    , batch_id
    , batch_run_date
    , batch_insert_ts as upstream_insert_ts
    , current_timestamp() as batch_insert_ts
    , unique_id
from current_data
where rn = 1
