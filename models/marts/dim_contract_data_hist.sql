{{ config(
    materialized = 'incremental',
    unique_key = ['ledger_key_hash', 'start_date'],
    partition_by = {
        "field": "start_date",
        "data_type": "date",
        "granularity": "month"
    },
    cluster_by = ["ledger_key_hash", "start_date", "row_hash"],
    tags = ["soroban_analytics"]
) }}

/*
Model: dim_contract_data_hist

Description:
------------
This model implements Slowly Changing Dimension (SCD) Type 2 logic to track historical changes
in contract data over time. The model supports initial loads and incremental updates.

Features:
---------
1. Creates a record for each change in `ledger_key_hash`.
2. Applies change tracking logic using row hash comparison to detect updates.
3. Implements date chaining to maintain historical records, marking `is_current` for the latest active record.

Usage:
------
Compile:
    dbt compile --models dim_contract_data_hist

Run:
    dbt run --models dim_contract_data_hist --full-refresh
    dbt run --models dim_contract_data_hist
*/

-- Load latest changes from transformed contract data, applying incremental filter
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
            , batch_run_date
            , row_hash
        from {{ ref('int_transform_contract_data') }}
        {% if is_incremental() %}
            where closed_at > (select coalesce(max(closed_at), '2000-01-01T00:00:00+00:00') from {{ this }})
        {% endif %}
    )

    -- Get existing history records for affected contracts, or create empty shell for initial load
    , target_data as (
        {% if is_incremental() %}
            select *
            from {{ this }}
            where ledger_key_hash in (select distinct ledger_key_hash from source_data)
        {% else %}
        select
              CAST(NULL AS STRING) AS ledger_key_hash
            , CAST(NULL AS DATE) AS start_date
            , CAST(NULL AS STRING) AS contract_id
            , CAST(NULL AS STRING) AS contract_durability
            , CAST(NULL AS STRING) AS asset_code
            , CAST(NULL AS STRING) AS asset_issuer
            , CAST(NULL AS STRING) AS asset_type
            , CAST(NULL AS NUMERIC) AS balance
            , CAST(NULL AS STRING) AS balance_holder
            , CAST(NULL AS TIMESTAMP) AS contract_create_ts
            , CAST(NULL AS TIMESTAMP) AS contract_delete_ts
            , CAST(NULL AS TIMESTAMP) AS closed_at
            , CAST(NULL AS DATE) AS end_date
            , CAST(NULL AS BOOLEAN) AS is_current
            , CAST(NULL AS TIMESTAMP) AS airflow_start_ts
            , CAST(NULL AS STRING) AS batch_id
            , CAST(NULL AS DATETIME) AS batch_run_date
            , CAST(NULL AS STRING) AS row_hash
            , CAST(NULL AS TIMESTAMP) AS dw_load_ts
            , CAST(NULL AS TIMESTAMP) AS dw_update_ts
        from source_data
        where 1 = 0
    {% endif %}
    )

    -- Detect changes by comparing source and target data attributes
    -- Outputs: Change type (Insert/Update/NoChange) based on row hash comparison
    , combined_cdc_data as (
        select
            coalesce(s.ledger_key_hash, t.ledger_key_hash) as ledger_key_hash
            , coalesce(s.start_date, t.start_date) as start_date
            , s.contract_id as source_contract_id
            , t.contract_id as target_contract_id
            , s.contract_durability as source_contract_durability
            , t.contract_durability as target_contract_durability
            , s.asset_code as source_asset_code
            , t.asset_code as target_asset_code
            , s.asset_issuer as source_asset_issuer
            , t.asset_issuer as target_asset_issuer
            , s.asset_type as source_asset_type
            , t.asset_type as target_asset_type
            , s.balance as source_balance
            , t.balance as target_balance
            , s.balance_holder as source_balance_holder
            , t.balance_holder as target_balance_holder
            , s.contract_create_ts as source_contract_create_ts
            , t.contract_create_ts as target_contract_create_ts
            , s.contract_delete_ts as source_contract_delete_ts
            , t.contract_delete_ts as target_contract_delete_ts
            , s.closed_at as source_closed_at
            , t.closed_at as target_closed_at
            , t.end_date as target_end_date
            , t.is_current as target_is_current
            , s.airflow_start_ts as source_airflow_start_ts
            , t.airflow_start_ts as target_airflow_start_ts
            , s.batch_id as source_batch_id
            , t.batch_id as target_batch_id
            , s.batch_run_date as source_batch_run_date
            , t.batch_run_date as target_batch_run_date
            , s.row_hash as source_row_hash
            , t.row_hash as target_row_hash
            , t.dw_load_ts as target_dw_load_ts
            , t.dw_update_ts as target_dw_update_ts
            , case
                when t.ledger_key_hash is null then 'Insert'  -- New record
                when s.row_hash != t.row_hash then 'Update'  -- Changed record
                else 'NoChange'  -- No change in the current record
            end as change_type
        from source_data as s
        full outer join target_data as t
            on s.ledger_key_hash = t.ledger_key_hash
            and s.start_date = t.start_date
    )

    -- Date chaining for SCD Type 2 with separated CTEs
    , date_chained as (
        select
            cdc.*
            , lead(cdc.start_date) over (partition by cdc.ledger_key_hash order by cdc.start_date) as next_start_date
            -- Operation Types:
            -- INSERT_NEW_KEY: First occurrence of a ledger_key_hash
            -- START_NEW_VERSION: New version of existing record due to attribute changes
            -- END_CURRENT_VERSION: Close current version due to future changes
            -- KEEP_CURRENT: No changes needed, maintain current record
            , case
                when cdc.change_type = 'Insert' then 'INSERT_NEW_KEY'
                when cdc.change_type = 'Update' then 'START_NEW_VERSION'
                when
                    cdc.change_type = 'NoChange'
                    and lead(cdc.start_date) over (partition by cdc.ledger_key_hash order by cdc.start_date) is not null
                    then 'END_CURRENT_VERSION'
                else 'KEEP_CURRENT'
            end as operation_type
        from combined_cdc_data as cdc
    )

    -- Final data processing with all transformations
    , final_data as (
        select
            dc.ledger_key_hash
            , coalesce(dc.source_contract_id, dc.target_contract_id) as contract_id
            , coalesce(dc.source_contract_durability, dc.target_contract_durability) as contract_durability
            , coalesce(dc.source_asset_code, dc.target_asset_code) as asset_code
            , coalesce(dc.source_asset_issuer, dc.target_asset_issuer) as asset_issuer
            , coalesce(dc.source_asset_type, dc.target_asset_type) as asset_type
            , coalesce(dc.source_balance, dc.target_balance) as balance
            , coalesce(dc.source_balance_holder, dc.target_balance_holder) as balance_holder
            , coalesce(dc.source_contract_create_ts, dc.target_contract_create_ts) as contract_create_ts
            , coalesce(dc.source_contract_delete_ts, dc.target_contract_delete_ts) as contract_delete_ts
            , coalesce(dc.source_closed_at, dc.target_closed_at) as closed_at
            , dc.start_date
            , coalesce(date_sub(dc.next_start_date, interval 1 day), date('9999-12-31')) as end_date
            , coalesce(row_number() over (partition by dc.ledger_key_hash order by dc.start_date desc) = 1, false) as is_current
            , coalesce(dc.source_airflow_start_ts, dc.target_airflow_start_ts) as airflow_start_ts
            , coalesce(dc.source_batch_id, dc.target_batch_id) as batch_id
            , coalesce(dc.source_batch_run_date, dc.target_batch_run_date) as batch_run_date
            , coalesce(dc.source_row_hash, dc.target_row_hash) as row_hash
            , coalesce(dc.target_dw_load_ts, current_timestamp()) as dw_load_ts
            , current_timestamp() as dw_update_ts
            , dc.operation_type
        from date_chained as dc
        where dc.operation_type in ('INSERT_NEW_KEY', 'START_NEW_VERSION', 'END_CURRENT_VERSION')
    )

select
    ledger_key_hash
    , contract_id
    , start_date
    , end_date
    , is_current
    , contract_create_ts
    , contract_delete_ts
    , closed_at
    , contract_durability
    , asset_code
    , asset_issuer
    , asset_type
    , balance
    , balance_holder
    , row_hash
    , batch_id
    , batch_run_date
    , airflow_start_ts
    , dw_load_ts
    , dw_update_ts
from final_data
