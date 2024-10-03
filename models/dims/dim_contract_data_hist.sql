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
Model: dim_contract_data_hist

Description:
------------
This model implements Slowly Changing Dimension (SCD) Type 2 logic to track historical changes
in contract data over time. The model supports initial loads, incremental updates, and recovery scenarios.

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
    dbt compile --models dim_contract_data_hist

Run:
    dbt run --models dim_contract_data_hist --full-refresh
    dbt run --models dim_contract_data_hist
*/

-- Variable to detect if the model is running in recovery mode
{% set recovery_mode = var('recovery', false) %}

-- Source Data: Load contract data from the staging model
WITH source_data AS (
    SELECT
        contract_id,
        ledger_key_hash,
        contract_durability,
        asset_code,
        asset_issuer,
        asset_type,
        balance,
        balance_holder,
        contract_create_ts,
        contract_delete_ts,
        closed_at,
        DATE(closed_at) AS start_date,
        airflow_start_ts,
        batch_id,
        SAFE_CAST(batch_run_date AS DATETIME) AS batch_run_date,
        row_hash,
        NULL AS end_date
    FROM {{ ref('int_transform_contract_data') }}
),

-- Target Data CTE uses this section to select relevant target records based on First Run, Incremental or Recoevery
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
            CAST(NULL AS STRING) AS contract_id,
            CAST(NULL AS STRING) AS contract_durability,
            CAST(NULL AS STRING) AS asset_code,
            CAST(NULL AS STRING) AS asset_issuer,
            CAST(NULL AS STRING) AS asset_type,
            CAST(NULL AS NUMERIC) AS balance,
            CAST(NULL AS STRING) AS balance_holder,
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
        t.start_date AS target_start_date,
        t.end_date AS target_end_date,
        t.is_current AS target_is_current,
        t.row_hash AS target_row_hash,
        t.dw_insert_ts AS target_dw_insert_ts,
        t.dw_update_ts AS target_dw_update_ts,
        t.closed_at AS target_closed_at,
        t.asset_code AS target_asset_code,
        t.asset_issuer AS target_asset_issuer,
        t.asset_type AS target_asset_type,
        t.balance AS target_balance,
        t.balance_holder AS target_balance_holder,
        t.contract_id AS target_contract_id,
        t.contract_durability AS target_contract_durability,
        t.contract_create_ts AS target_contract_create_ts,
        t.contract_delete_ts AS target_contract_delete_ts,
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
    -- Gather new Inserts and Updates to existing Ledgers
    SELECT
        ledger_key_hash,
        closed_at,
        start_date,
        COALESCE(DATE_SUB(next_start_date, INTERVAL 1 DAY), DATE('9999-12-31')) AS end_date,
        CASE WHEN next_start_date IS NULL THEN TRUE ELSE FALSE END AS is_current,
        asset_code,
        asset_issuer,
        asset_type,
        balance,
        balance_holder,
        contract_id,
        contract_durability,
        contract_create_ts,
        contract_delete_ts,
        airflow_start_ts,
        batch_id,
        batch_run_date,
        row_hash,
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
        target_closed_at AS closed_at,
        target_start_date AS start_date,
        DATE_SUB(start_date, INTERVAL 1 DAY) AS end_date,
        FALSE AS is_current,
        target_asset_code AS asset_code,
        target_asset_issuer AS asset_issuer,
        target_asset_type AS asset_type,
        target_balance AS balance,
        target_balance_holder AS balance_holder,
        target_contract_id AS contract_id,
        target_contract_durability AS contract_durability,
        target_contract_create_ts AS contract_create_ts,
        target_contract_delete_ts AS contract_delete_ts,
        target_airflow_start_ts AS airflow_start_ts,
        target_batch_id AS batch_id,
        target_batch_run_date AS batch_run_date,
        target_row_hash AS row_hash,
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
    closed_at,
    start_date,
    end_date,
    is_current,
    asset_code,
    asset_issuer,
    asset_type,
    balance,
    balance_holder,
    contract_id,
    contract_durability,
    contract_create_ts,
    contract_delete_ts,
    batch_id,
    batch_run_date,
    row_hash,
    airflow_start_ts,
    dw_insert_ts,
    dw_update_ts
FROM final_data
