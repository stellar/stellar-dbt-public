{{ config(
    materialized = 'incremental',
    unique_key = ['ledger_key_hash', 'start_date'],
    on_schema_change = 'sync_all_columns',
    partition_by = {
        "field": "start_date",
        "data_type": "date",
        "granularity": "day"
    },
    cluster_by = ["ledger_key_hash", "start_date"],
    tags = ["soroban_analytics"],
    enabled = true
) }}

/*
Model: dim_contract_code_hist

Description:
------------
This model implements Slowly Changing Dimension (SCD) Type 2 logic to track historical changes
in contract code data over time. The model supports initial loads, incremental updates, and recovery scenarios.

Features:
---------
1. Creates a record for each change in `ledger_key_hash`.
2. Handles incremental loads using Airflow variables for recovery mode.
3. Applies change tracking logic using row hash comparison to detect updates.
4. Date chaining to maintain historical records.
5. Updates `is_current` flag to mark the latest active record per `ledger_key_hash`.

Usage:
------
Compile:
    dbt compile --models dim_contract_code_hist

Run:
    dbt run --models dim_contract_code_hist --full-refresh
    dbt run --models dim_contract_code_hist
*/

-- Variable to detect if the model is running in recovery mode
{% set recovery_mode = var('recovery', false) %}

-- Source Data: Load contract code data from the intermediate model
WITH source_data AS (
    SELECT
        contract_code_hash,
        ledger_key_hash,
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
        contract_create_ts,
        contract_delete_ts,
        closed_at,
        DATE(closed_at) AS start_date,
        airflow_start_ts,
        batch_id,
        SAFE_CAST(batch_run_date AS DATETIME) AS batch_run_date,
        row_hash,
        NULL AS end_date
    FROM {{ ref('int_transform_contract_code') }}
),

-- Target Data: Select relevant target records based on the mode (First Run, Incremental, or Recovery)
target_data AS (
    {% if is_incremental() %}
        {% if recovery_mode %}
            -- In recovery mode, pull all relevant target records for complete date chaining
            SELECT *
            FROM {{ this }}
            WHERE ledger_key_hash IN (SELECT DISTINCT ledger_key_hash FROM source_data)
        {% else %}
            -- For regular incremental runs, only pull current records related to the source data
            SELECT *
            FROM {{ this }}
            WHERE is_current = TRUE
            AND ledger_key_hash IN (SELECT DISTINCT ledger_key_hash FROM source_data)
        {% endif %}
    {% else %}
        -- Initial load when the target table doesn't exist: create a dummy shell with placeholder values
        SELECT
            CAST(NULL AS STRING) AS ledger_key_hash,
            CAST(NULL AS DATE) AS start_date,
            CAST(NULL AS STRING) AS contract_code_hash,
            CAST(NULL AS INT64) AS n_instructions,
            CAST(NULL AS INT64) AS n_functions,
            CAST(NULL AS INT64) AS n_globals,
            CAST(NULL AS INT64) AS n_table_entries,
            CAST(NULL AS INT64) AS n_types,
            CAST(NULL AS INT64) AS n_data_segments,
            CAST(NULL AS INT64) AS n_elem_segments,
            CAST(NULL AS INT64) AS n_imports,
            CAST(NULL AS INT64) AS n_exports,
            CAST(NULL AS INT64) AS n_data_segment_bytes,
            CAST(NULL AS TIMESTAMP) AS contract_create_ts,
            CAST(NULL AS TIMESTAMP) AS contract_delete_ts,
            CAST(NULL AS TIMESTAMP) AS closed_at,
            CAST(NULL AS TIMESTAMP) AS airflow_start_ts,
            CAST(NULL AS STRING) AS batch_id,
            CAST(NULL AS DATETIME) AS batch_run_date,
            CAST(NULL AS STRING) AS row_hash,
            CAST(NULL AS DATE) AS end_date,
            TRUE AS is_current,
            CURRENT_TIMESTAMP() AS dw_insert_ts,
            CURRENT_TIMESTAMP() AS dw_update_ts
        FROM source_data
        WHERE 1 = 0
    {% endif %}
),

-- Combine source and target data for change tracking
combined_data AS (
    SELECT
        s.*,
        t.contract_code_hash AS target_contract_code_hash,
        t.n_instructions AS target_n_instructions,
        t.n_functions AS target_n_functions,
        t.n_globals AS target_n_globals,
        t.n_table_entries AS target_n_table_entries,
        t.n_types AS target_n_types,
        t.n_data_segments AS target_n_data_segments,
        t.n_elem_segments AS target_n_elem_segments,
        t.n_imports AS target_n_imports,
        t.n_exports AS target_n_exports,
        t.n_data_segment_bytes AS target_n_data_segment_bytes,
        t.contract_create_ts AS target_contract_create_ts,
        t.contract_delete_ts AS target_contract_delete_ts,
        t.closed_at AS target_closed_at,
        t.start_date AS target_start_date,
        t.end_date AS target_end_date,
        t.is_current AS target_is_current,
        t.row_hash AS target_row_hash,
        t.dw_insert_ts AS target_dw_insert_ts,
        t.dw_update_ts AS target_dw_update_ts,
        t.airflow_start_ts AS target_airflow_start_ts,
        t.batch_id AS target_batch_id,
        t.batch_run_date AS target_batch_run_date,
        CASE
            WHEN t.ledger_key_hash IS NULL THEN 'Insert'  -- New record
            WHEN s.row_hash != t.row_hash THEN 'Update'  -- Changed record
            ELSE 'NoChange'  -- No change in the current record
        END AS change_type
    FROM source_data s
    LEFT JOIN target_data t ON s.ledger_key_hash = t.ledger_key_hash
),

-- Date chaining to maintain historical records
date_chained AS (
    SELECT
        *,
        LEAD(start_date) OVER (PARTITION BY ledger_key_hash ORDER BY start_date) AS next_start_date
    FROM combined_data
),

final_data AS (
    -- Gather new Inserts and Updates to existing ledgers
    SELECT
        ledger_key_hash,
        contract_code_hash,
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
        contract_create_ts,
        contract_delete_ts,
        closed_at,
        start_date,
        COALESCE(DATE_SUB(next_start_date, INTERVAL 1 DAY), DATE('9999-12-31')) AS end_date,
        CASE WHEN next_start_date IS NULL THEN TRUE ELSE FALSE END AS is_current,
        batch_id,
        batch_run_date,
        row_hash,
        airflow_start_ts,
        CURRENT_TIMESTAMP() AS dw_insert_ts,
        CURRENT_TIMESTAMP() AS dw_update_ts,
        change_type
    FROM date_chained
    WHERE change_type IN ('Insert', 'Update')

    {% if is_incremental() %}
    UNION ALL

    -- Close out previous current records for updates (only during incremental runs)
    SELECT
        ledger_key_hash,
        target_contract_code_hash AS contract_code_hash,
        target_n_instructions AS n_instructions,
        target_n_functions AS n_functions,
        target_n_globals AS n_globals,
        target_n_table_entries AS n_table_entries,
        target_n_types AS n_types,
        target_n_data_segments AS n_data_segments,
        target_n_elem_segments AS n_elem_segments,
        target_n_imports AS n_imports,
        target_n_exports AS n_exports,
        target_n_data_segment_bytes AS n_data_segment_bytes,
        target_contract_create_ts AS contract_create_ts,
        target_contract_delete_ts AS contract_delete_ts,
        target_closed_at AS closed_at,
        target_start_date AS start_date,
        DATE_SUB(target_start_date, INTERVAL 1 DAY) AS end_date,
        FALSE AS is_current,
        target_batch_id AS batch_id,
        target_batch_run_date AS batch_run_date,
        target_row_hash AS row_hash,
        target_airflow_start_ts AS airflow_start_ts,
        target_dw_insert_ts AS dw_insert_ts,
        CURRENT_TIMESTAMP() AS dw_update_ts,
        'Prev Current' AS change_type
    FROM combined_data
    WHERE change_type = 'Update' AND target_is_current = TRUE
    {% endif %}
)

-- Select only the required columns in the final table
SELECT
    ledger_key_hash,
    contract_code_hash,
    closed_at,
    start_date,
    end_date,
    is_current,
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
    contract_create_ts,
    contract_delete_ts,
    batch_id,
    batch_run_date,
    row_hash,
    airflow_start_ts,
    dw_insert_ts,
    dw_update_ts
FROM final_data
