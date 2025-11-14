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
        from {{ ref('stg_contract_code') }} as cc
        where
            true
            -- Need to add/subtract one day to the window boundaries
            -- because this model runs at 30 min increments.
            -- Without the additional date buffering the following would occur
            -- * batch_start_date == '2025-01-01 01:00:00' --> '2025-01-01'
            -- * batch_end_date == '2025-01-01 01:30:00' --> '2025-01-01'
            -- * '2025-01-01 <= closed_at < '2025-01-01' would never have any data to processes
            and closed_at < timestamp(date_add(date('{{ var("batch_end_date") }}'), interval 1 day))
        {% if is_incremental() %}
            -- The extra day date_sub is useful in the case the first scheduled run for a day is skipped
            -- because the DAG is configured with catchup=false
            and closed_at >= timestamp(date_sub(date('{{ var("batch_start_date") }}'), interval 1 day))
    {% endif %}
        qualify row_number()
            over (
                partition by cc.contract_code_hash
                order by cc.closed_at desc
            )
        = 1
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
