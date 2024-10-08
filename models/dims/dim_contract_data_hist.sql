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
with
    source_data as (
        select
            contract_id
            , ledger_key_hash
            , contract_durability
            , asset_code
            , asset_issuer
            , asset_type
            , balance
            , balance_holder
            , contract_create_ts
            , contract_delete_ts
            , closed_at
            , date(closed_at) as start_date
            , airflow_start_ts
            , batch_id
            , safe_cast(batch_run_date as datetime) as batch_run_date
            , row_hash
            , null as end_date
        from {{ ref('int_transform_contract_data') }}
    )

    -- Target Data CTE uses this section to select relevant target records based on First Run, Incremental or Recoevery
    , target_data as (
        {% if is_incremental() %}
            {% if recovery_mode %}
            -- In recovery mode, pull all relevant target records for complete date chaining
            SELECT *
            FROM {{ this }}
            WHERE ledger_key_hash IN (SELECT DISTINCT ledger_key_hash FROM source_data)
        {% else %}
            -- For regular incremental runs, only pull current records related to the source data
                select *
                from {{ this }}
                where
                    is_current = true
                    and ledger_key_hash in (select distinct ledger_key_hash from source_data)
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
    )

    -- Combine source and target data for change tracking
    , combined_data as (
        select
            s.*
            , t.start_date as target_start_date
            , t.end_date as target_end_date
            , t.is_current as target_is_current
            , t.row_hash as target_row_hash
            , t.dw_insert_ts as target_dw_insert_ts
            , t.dw_update_ts as target_dw_update_ts
            , t.closed_at as target_closed_at
            , t.asset_code as target_asset_code
            , t.asset_issuer as target_asset_issuer
            , t.asset_type as target_asset_type
            , t.balance as target_balance
            , t.balance_holder as target_balance_holder
            , t.contract_id as target_contract_id
            , t.contract_durability as target_contract_durability
            , t.contract_create_ts as target_contract_create_ts
            , t.contract_delete_ts as target_contract_delete_ts
            , t.airflow_start_ts as target_airflow_start_ts
            , t.batch_id as target_batch_id
            , t.batch_run_date as target_batch_run_date
            , case
                when t.ledger_key_hash is null then 'Insert'  -- New record
                when s.row_hash != t.row_hash then 'Update'  -- Changed record
                else 'NoChange'  -- No change in the current record
            end as change_type
        from source_data as s
        left join target_data as t on s.ledger_key_hash = t.ledger_key_hash
    )

    -- Date chaining to maintain historical records
    , date_chained as (
        select
            *
            , lead(start_date) over (partition by ledger_key_hash order by start_date) as next_start_date
        from combined_data
    )

    , final_data as (
    -- Gather new Inserts and Updates to existing Ledgers
        select
            ledger_key_hash
            , closed_at
            , start_date
            , coalesce(date_sub(next_start_date, interval 1 day), date('9999-12-31')) as end_date
            , coalesce(next_start_date is null, false) as is_current
            , asset_code
            , asset_issuer
            , asset_type
            , balance
            , balance_holder
            , contract_id
            , contract_durability
            , contract_create_ts
            , contract_delete_ts
            , airflow_start_ts
            , batch_id
            , batch_run_date
            , row_hash
            , current_timestamp() as dw_insert_ts
            , current_timestamp() as dw_update_ts
            , change_type
        from date_chained
        where change_type in ('Insert', 'Update')

        {% if is_incremental() %}
            union all

            -- Close out previous current records for updates (only during incremental runs)
            select
                ledger_key_hash
                , target_closed_at as closed_at
                , target_start_date as start_date
                , date_sub(start_date, interval 1 day) as end_date
                , false as is_current
                , target_asset_code as asset_code
                , target_asset_issuer as asset_issuer
                , target_asset_type as asset_type
                , target_balance as balance
                , target_balance_holder as balance_holder
                , target_contract_id as contract_id
                , target_contract_durability as contract_durability
                , target_contract_create_ts as contract_create_ts
                , target_contract_delete_ts as contract_delete_ts
                , s.airflow_start_ts
                , s.batch_id
                , s.batch_run_date
                , target_row_hash as row_hash
                , target_dw_insert_ts as dw_insert_ts
                , current_timestamp() as dw_update_ts
                , 'Prev Current' as change_type
            from combined_data
            where change_type = 'Update' and target_is_current = true
        {% endif %}
    )

-- Select only the required columns in the final table
select
    ledger_key_hash
    , closed_at
    , start_date
    , end_date
    , is_current
    , asset_code
    , asset_issuer
    , asset_type
    , balance
    , balance_holder
    , contract_id
    , contract_durability
    , contract_create_ts
    , contract_delete_ts
    , batch_id
    , batch_run_date
    , row_hash
    , airflow_start_ts
    , dw_insert_ts
    , dw_update_ts
from final_data
