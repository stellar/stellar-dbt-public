{{ config(
    materialized = 'table',
    unique_key = ['ledger_key_hash'],
    partition_by = {
        "field": "TIMESTAMP_TRUNC(closed_at, MONTH)",
        "data_type": "DATE"
    },
    cluster_by = ["ledger_key_hash"],
    tags = ["soroban_analytics", "dimension", "daily"]
) }}

-- Model: dim_contract_data_current
--
-- Description:
-- ------------
-- This model filters the `dim_contract_data_hist` table to select only the current records (where `is_current` is TRUE).
-- This creates a snapshot of the latest active state for each `ledger_key_hash`.
--
-- Features:
-- ---------
-- 1. Selects only the records where `is_current` is TRUE from the historical table.
-- 2. Includes relevant columns to represent the current state of each contract.
--
-- Usage:
-- ------
-- Compile:
--     dbt compile --models dim_contract_data_current
--
-- Run:
--     dbt run --models dim_contract_data_current

with
    current_records as (
        select
            ledger_key_hash
            , contract_id
            , contract_durability
            , contract_create_ts
            , contract_delete_ts
            , closed_at
            , asset_code
            , asset_issuer
            , asset_type
            , balance
            , balance_holder
            , batch_id
            , batch_run_date
            , airflow_start_ts
        from {{ ref('dim_contract_data_hist') }}
        where is_current = true  -- Select only current version of each contract
    )

-- Final output: Current state snapshot of all contracts
select
    ledger_key_hash
    , contract_id
    , contract_durability
    , contract_create_ts
    , contract_delete_ts
    , closed_at
    , asset_code
    , asset_issuer
    , asset_type
    , balance
    , balance_holder
    , batch_id
    , batch_run_date
    , airflow_start_ts
    , current_timestamp() as dw_load_ts  -- Load timestamp to track data freshness
from current_records
