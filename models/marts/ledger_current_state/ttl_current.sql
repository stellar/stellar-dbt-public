{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["key_hash"],
    "cluster_by": ["key_hash"],
    "tags": ["current_state"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
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
                    order by ttl.closed_at desc
                ) as rn
        from {{ ref('stg_ttl') }} as ttl
        {% if is_incremental() %}
            -- limit the number of partitions fetched incrementally
            where
                TIMESTAMP(ttl.closed_at) >= TIMESTAMP_SUB('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL 7 DAY )
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
    , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
from current_expiration
where rn = 1
