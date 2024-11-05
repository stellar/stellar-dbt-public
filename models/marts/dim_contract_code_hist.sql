{{
    config(
        materialized = 'incremental',
        unique_key = ['ledger_key_hash', 'start_date'],
        cluster_by = ["ledger_key_hash", "start_date", "row_hash"],
        tags = ["dim_contract_code_hist", "soroban_analytics", "dimension", "scd-2", "daily"]
    )
}}

/*
Model: dim_contract_code_hist

Description:
------------
This model implements Slowly Changing Dimension (SCD) Type 2 logic to track historical changes
in contract code data over time. The model supports initial loads and incremental updates, including catch-up.

Features:
---------
1. Creates a record for each change in `ledger_key_hash`.
2. Applies change tracking logic using row hash comparison to detect updates.
3. Implements date chaining to maintain historical records, marking `is_current` for the latest active record.
4. Supports multi-day catch-up scenarios by processing all relevant records based on the incremental logic.

Usage:
------
Compile:
    dbt compile --models dim_contract_code_hist

Run:
    dbt run --models dim_contract_code_hist --full-refresh
    dbt run --models dim_contract_code_hist
*/

-- Load latest changes from transformed contract code data, applying incremental filter
with
    source_data as (
        select
            contract_code_hash
            , ledger_key_hash
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
            , contract_create_ts
            , contract_delete_ts
            , closed_at
            , date(closed_at) as start_date
            , airflow_start_ts
            , batch_id
            , batch_run_date
            , row_hash
        from {{ ref('int_transform_contract_code') }}
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
            , CAST(NULL AS STRING) AS contract_code_hash
            , CAST(NULL AS INT64) AS n_instructions
            , CAST(NULL AS INT64) AS n_functions
            , CAST(NULL AS INT64) AS n_globals
            , CAST(NULL AS INT64) AS n_table_entries
            , CAST(NULL AS INT64) AS n_types
            , CAST(NULL AS INT64) AS n_data_segments
            , CAST(NULL AS INT64) AS n_elem_segments
            , CAST(NULL AS INT64) AS n_imports
            , CAST(NULL AS INT64) AS n_exports
            , CAST(NULL AS INT64) AS n_data_segment_bytes
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
            , s.contract_code_hash as source_contract_code_hash
            , t.contract_code_hash as target_contract_code_hash
            , s.n_instructions as source_n_instructions
            , t.n_instructions as target_n_instructions
            , s.n_functions as source_n_functions
            , t.n_functions as target_n_functions
            , s.n_globals as source_n_globals
            , t.n_globals as target_n_globals
            , s.n_table_entries as source_n_table_entries
            , t.n_table_entries as target_n_table_entries
            , s.n_types as source_n_types
            , t.n_types as target_n_types
            , s.n_data_segments as source_n_data_segments
            , t.n_data_segments as target_n_data_segments
            , s.n_elem_segments as source_n_elem_segments
            , t.n_elem_segments as target_n_elem_segments
            , s.n_imports as source_n_imports
            , t.n_imports as target_n_imports
            , s.n_exports as source_n_exports
            , t.n_exports as target_n_exports
            , s.n_data_segment_bytes as source_n_data_segment_bytes
            , t.n_data_segment_bytes as target_n_data_segment_bytes
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
            , coalesce(dc.source_contract_code_hash, dc.target_contract_code_hash) as contract_code_hash
            , coalesce(dc.source_n_instructions, dc.target_n_instructions) as n_instructions
            , coalesce(dc.source_n_functions, dc.target_n_functions) as n_functions
            , coalesce(dc.source_n_globals, dc.target_n_globals) as n_globals
            , coalesce(dc.source_n_table_entries, dc.target_n_table_entries) as n_table_entries
            , coalesce(dc.source_n_types, dc.target_n_types) as n_types
            , coalesce(dc.source_n_data_segments, dc.target_n_data_segments) as n_data_segments
            , coalesce(dc.source_n_elem_segments, dc.target_n_elem_segments) as n_elem_segments
            , coalesce(dc.source_n_imports, dc.target_n_imports) as n_imports
            , coalesce(dc.source_n_exports, dc.target_n_exports) as n_exports
            , coalesce(dc.source_n_data_segment_bytes, dc.target_n_data_segment_bytes) as n_data_segment_bytes
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
        where dc.operation_type in (
            'INSERT_NEW_KEY'
            , 'START_NEW_VERSION'
            , 'END_CURRENT_VERSION'
        )
    )

select
    ledger_key_hash
    , contract_code_hash
    , start_date
    , end_date
    , is_current
    , contract_create_ts
    , contract_delete_ts
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
    , row_hash
    , batch_id
    , batch_run_date
    , airflow_start_ts
    , dw_load_ts
    , dw_update_ts
from final_data
