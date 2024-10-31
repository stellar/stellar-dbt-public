{{
    config(
        materialized = 'incremental',
        unique_key = ['ledger_key_hash', 'closed_at'],
        cluster_by = ["ledger_key_hash", "closed_at"],
        tags = ["soroban_analytics", "intermediate", "daily"]
    )
}}
/*
Model: int_incr_contract_code

Description:
------------
This intermediate model handles the incremental loading of contract code from the staging layer.
It processes only new or updated data up to the previous day based on `execution_date`.

Features:
---------
1. Uses execution_date from Airflow to determine the processing window.
2. Processes new or updated records for completed days up to the previous day.
3. Selects only the latest entry per `ledger_key_hash` per day within the processing window.

Usage:
------
Compile:
 dbt compile --models int_incr_contract_code
 dbt compile --models int_incr_contract_code --vars '{"execution_date": "2024-10-25T00:00:00+00:00"}'
Run:
 dbt run --models int_incr_contract_code --full-refresh
 dbt run --models int_incr_contract_code
 dbt run --models int_incr_contract_code --vars '{"execution_date": "2024-10-25T00:00:00+00:00"}'
*/

-- Set the execution date (use Airflow value, fallback to dbt default if absent)
{% set execution_date = var('execution_date', dbt_airflow_macros.ts(timezone=none)) %}

with
    source_data as (
        select
            contract_code_hash
            , ledger_key_hash
            , last_modified_ledger
            , ledger_entry_change
            , ledger_sequence
            , deleted
            , closed_at
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
        from {{ ref('stg_contract_code') }}
        where
        -- Process only completed days up to execution_date for incremental loads
            date(closed_at) < date('{{ execution_date }}')

            -- Process records inserted since the last load (incremental only)
            {% if is_incremental() %}
                and date(closed_at) >= (select coalesce(max(date(closed_at)), '2000-01-01') from {{ this }})
            {% endif %}
    )
    , ranked_data as (
        select
            *
            , row_number() over (
                partition by ledger_key_hash, cast(closed_at as date)
                order by closed_at desc, ledger_sequence desc
            ) as rn
        from source_data
    )

-- Pick only the latest change per ledger per day
select
    ledger_key_hash
    , contract_code_hash
    , last_modified_ledger
    , ledger_entry_change
    , ledger_sequence
    , deleted
    , closed_at
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
    , cast('{{ execution_date }}' as timestamp) as airflow_start_ts
    , current_timestamp() as dw_load_ts
from ranked_data
where rn = 1
