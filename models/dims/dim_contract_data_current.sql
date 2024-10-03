{{ config(
    materialized = 'table',
    unique_key = ['ledger_key_hash'],
    on_schema_change = 'sync_all_columns',
    partition_by = {
        "field": "closed_at",
        "data_type": "timestamp"
    },
    cluster_by = ["contract_id"],
    tags = ["soroban_analytics"],
    enabled = true
) }}

-- Model: dim_contract_data_current
--
-- Description:
-- ------------
-- This model filters the `dim_contract_data_hist` table to select only the current records (where `is_current` is TRUE).
-- This allows us to create a snapshot of the latest active state for each `ledger_key_hash`.
--
-- Features:
-- ---------
-- 1. Selects only the records where `is_current` is TRUE from the historical table.
-- 2. Includes the relevant columns to represent the current state of each contract.
-- 3. Adds a `dw_load_ts` column to capture the timestamp when the data was loaded into the data warehouse.
--
-- Usage:
-- ------
-- Compile:
--     dbt compile --models dim_contract_data_current
--
-- Run:
--     dbt run --models dim_contract_data_current

WITH current_records AS (
    SELECT
        ledger_key_hash,
        contract_id,
        contract_durability,
        contract_create_ts,
        contract_delete_ts,
        closed_at,
        asset_code,
        asset_issuer,
        asset_type,
        balance,
        balance_holder,
        batch_id,
        batch_run_date,
        airflow_start_ts,
        CURRENT_TIMESTAMP() AS dw_load_ts
    FROM {{ ref('dim_contract_data_hist') }}
    WHERE is_current IS TRUE
)

-- Final Output: Selecting only current records for each `ledger_key_hash`
SELECT
    ledger_key_hash,
    contract_id,
    contract_durability,
    contract_create_ts,
    contract_delete_ts,
    closed_at,
    asset_code,
    asset_issuer,
    asset_type,
    balance,
    balance_holder,
    batch_id,
    batch_run_date,
    airflow_start_ts,
    dw_load_ts
FROM current_records
