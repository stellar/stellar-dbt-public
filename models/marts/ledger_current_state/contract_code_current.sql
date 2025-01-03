{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["contract_code_hash"],
    "cluster_by": ["contract_code_hash"],
    "tags": ["current_state"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
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
            , cc.n_instructions
            , cc.n_functions
            , cc.n_globals
            , cc.n_table_entries
            , cc.n_types
            , cc.n_data_segments
            , cc.n_elem_segments
            , cc.n_imports
            , cc.n_exports
            , cc.n_data_segment_bytes
            , row_number()
                over (
                    partition by cc.contract_code_hash
                    order by cc.closed_at desc
                ) as rn
        from {{ ref('stg_contract_code') }} as cc
        {% if is_incremental() %}
            -- limit the number of partitions fetched incrementally
            where
                TIMESTAMP(cc.closed_at) >= TIMESTAMP_SUB('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL 7 day )
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
    , n_instructions
    , n_functions
    , n_globals
    , n_table_entries
    , n_types
    , n_data_segments
    , n_elem_segments
    , n_imports
    , n_exports
    , n_data_segment_bytes
    , batch_id
    , batch_run_date
    , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
from current_code
where rn = 1
