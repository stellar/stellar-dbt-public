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
            , row_number()
                over (
                    partition by ttl.key_hash
                    order by ttl.closed_at
                ) as rn
        from {{ ref('stg_ttl') }} as ttl
        {% if is_incremental() %}
            -- limit the number of partitions fetched incrementally
            where
                date(ttl.closed_at) >= date_sub(date('{{ dbt_airflow_macros.ds() }}'), interval 30 day)
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
from current_expiration
where rn = 1
