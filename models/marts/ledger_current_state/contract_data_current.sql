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
                TIMESTAMP(cd.closed_at) >= TIMESTAMP_SUB('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL 7 DAYS )
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
    , unique_id
from current_data
where rn = 1
