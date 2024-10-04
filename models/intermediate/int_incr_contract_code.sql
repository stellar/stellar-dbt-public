-- Materialized as a table for testing in lower environments. Change it to view later
{{ config(
    materialized = 'table',
    tags = ["soroban_analytics"],
    enabled = true
) }}

/*
Model: int_incr_contract_code

Description:
------------
This intermediate model handles the incremental loading of contract code from the staging layer.
It supports various loading scenarios including initial load, incremental updates, and data recovery.

Load Type: Truncate and Reload.

Features:
---------
1. Uses variables passed from Airflow to guide execution, including `execution_date`, `is_initial_load`, and `max_processed_date`.
2. Applies filtering logic based on recovery mode (single day, date range, or full recovery), initial load, or incremental load.
3. Selects the most recent record for each `ledger_key_hash` per day.
4. Processes the complete data up to the day before the `execution_date`.
5. Generates a unique identifier for each record using `ledger_key_hash` and `closed_at`.
6. Supports multiple loading scenarios:
    - Initial Load
    - Daily Incremental Load
    - Multi-day Incremental Catchup Load
    - Single Day Recovery Data Pull
    - Date Range Recovery Data Pull
    - Full Recovery (Full Refresh) Data Pull

Usage:
------
Compile :
    dbt compile --models int_incr_contract_code
    dbt compile --models int_incr_contract_code --vars '{"is_initial_load": true}'

Run:
    dbt run --models int_incr_contract_code --full-refresh
    dbt run --models int_incr_contract_code
    dbt run --models int_incr_contract_code --vars '{"is_initial_load": true}'
    dbt run --models int_incr_contract_code --vars '{"execution_date": "2024-10-03T00:00:00+00:00"}'
    dbt run --models int_incr_contract_code --vars '{"max_processed_date": "2024-10-01T00:00:00"}'
    dbt run --models int_incr_contract_code --vars '{"recovery": true, "recovery_type": "SingleDay", "recovery_date": "2024-09-20"}'
    dbt run --models int_incr_contract_code --vars '{"recovery": true, "recovery_type": "Range", "recovery_start_day": "2024-09-15", "recovery_end_day": "2024-09-25"}'
    dbt run --models int_incr_contract_code --vars '{"recovery": true, "recovery_type": "Full"}'
*/

-- Set the execution date from Airflow variable if provided; otherwise, use the current timestamp from dbt
{% if var('execution_date', none) is not none %}
    {% set execution_date = var('execution_date') %}
{% else %}
    {% set execution_date = dbt_airflow_macros.ts() %}
{% endif %}

-- Retrieve the Airflow variables passed for initial load and the maximum processed date
{% set is_initial_load = var('is_initial_load', false) %}
{% set max_processed_date = var('max_processed_date', '2000-01-01') %}

-- Retrieve recovery-related variables
{% set recovery_mode = var('recovery', false) %}
{% set recovery_type = var('recovery_type', 'None') %}
{% set recovery_date = var('recovery_date', 'N/A') %}
{% set recovery_start_day = var('recovery_start_day', 'N/A') %}
{% set recovery_end_day = var('recovery_end_day', 'N/A') %}

-- Debugging logs (optional): Remove these in production
{% if execute %}
    {{ log("Is table empty (Initial Load): " ~ is_initial_load, info=True) }}
    {{ log("Max processed date: " ~ max_processed_date, info=True) }}
    {{ log("Execution date: " ~ execution_date, info=True) }}
    {{ log("Airflow start timestamp: " ~ var("airflow_start_timestamp"), info=True) }}
    {{ log("Recovery Mode: " ~ recovery_mode, info=True) }}
    {{ log("Recovery Type: " ~ recovery_type, info=True) }}
    {{ log("Recovery Date: " ~ recovery_date, info=True) }}
    {{ log("Recovery Start Day: " ~ recovery_start_day, info=True) }}
    {{ log("Recovery End Day: " ~ recovery_end_day, info=True) }}
{% endif %}

-- Apply recovery flow filters and incremental logic to select the required data from the source table
with contract_code as (
    select
        cc.contract_code_hash,
        cc.ledger_key_hash,
        cc.last_modified_ledger,
        cc.ledger_entry_change,
        cc.ledger_sequence,
        cc.deleted,
        cc.closed_at,
        cc.n_instructions,
        cc.n_functions,
        cc.n_globals,
        cc.n_table_entries,
        cc.n_types,
        cc.n_data_segments,
        cc.n_elem_segments,
        cc.n_imports,
        cc.n_exports,
        cc.n_data_segment_bytes,
        cc.batch_insert_ts,
        -- Set the start timestamp passed from Airflow as `airflow_start_ts`
        cast('{{ var("airflow_start_timestamp") }}' as TIMESTAMP) as airflow_start_ts,
        cc.batch_id,
        cc.batch_run_date,
        -- Use `row_number()` to select the most recent record for each `ledger_key_hash` per day
        row_number() over (
            partition by cc.ledger_key_hash, cast(cc.closed_at as date)
            order by cc.closed_at desc, cc.ledger_sequence desc
        ) as row_num
    from {{ source('crypto_stellar', 'contract_code') }} as cc
    --from {{ ref('stg_contract_code') }} as cc
    where
        -- Apply recovery filters based on recovery variables passed from Airflow
        {{ apply_recovery_filters('cc', 'closed_at', execution_date) }}

        -- If not in recovery mode, apply initial load or incremental load logic
        {% if not var('recovery', false) %}
            {% if is_initial_load %}
                -- Initial load: If the table is empty, process all historical data until the day before `execution_date`
                or cc.closed_at < timestamp_trunc('{{ execution_date }}', day)
            {% else %}
                -- Incremental load: Process new data since the last `max_processed_date`
                or (cc.closed_at > CAST('{{ max_processed_date }}' AS TIMESTAMP)
                    and cc.closed_at < timestamp_trunc('{{ execution_date }}', day))
            {% endif %}
        {% endif %}
)

-- Select only the most recent record for each `ledger_key_hash` per day
select
    contract_code_hash,
    ledger_key_hash,
    last_modified_ledger,
    ledger_entry_change,
    ledger_sequence,
    n_instructions,
    n_functions,
    n_globals,
    n_table_entries,
    n_types,
    n_data_segments,
    n_elem_segments,
    n_imports,
    n_exports,
    n_data_segment_bytes,
    deleted,
    closed_at,
    batch_insert_ts,
    airflow_start_ts,
    batch_id,
    batch_run_date,
    current_timestamp() as dw_load_ts
from contract_code
where row_num = 1
