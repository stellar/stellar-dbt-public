{{ config(
    materialized = 'table',
    unique_key = ['key_hash'],
    partition_by = {
        "field": "TIMESTAMP_TRUNC(closed_at, MONTH)",
        "data_type": "DATE"
    },
    cluster_by = ["key_hash"],
    tags = ["dim_ttl_current", "soroban_analytics", "dimension", "daily"]
) }}

-- Model: dim_ttl_current
--
-- Description:
-- ------------
-- This model filters the `dim_ttl_hist` table to select only the current records (where `is_current` is TRUE).
-- This creates a snapshot of the latest active state for each `key_hash`.
--
-- Features:
-- ---------
-- 1. Selects only the records where `is_current` is TRUE from the historical table.
-- 2. Includes relevant columns to represent the current state of each TTL.
-- 3. Adds a `dw_load_ts` column to capture the timestamp when the data was loaded into the data warehouse.
--
-- Usage:
-- ------
-- Compile:
--     dbt compile --models dim_ttl_current
--
-- Run:
--     dbt run --models dim_ttl_current

with
    current_records as (
        select
            key_hash
            , live_until_ledger_seq
            , ttl_create_ts
            , ttl_delete_ts
            , closed_at
            , batch_id
            , batch_run_date
            , airflow_start_ts
        from {{ ref('dim_ttl_hist') }}
        where is_current = true  -- Select only current version of each TTL record
    )

-- Final output: Current state snapshot of all TTL records
select
    key_hash
    , live_until_ledger_seq
    , ttl_create_ts
    , ttl_delete_ts
    , closed_at
    , batch_id
    , batch_run_date
    , airflow_start_ts
    , current_timestamp() as dw_load_ts  -- Load timestamp to track data freshness
from current_records
