{{
    config(
        materialized = 'table',
        unique_key = ['ledger_key_hash', 'closed_at'],
        cluster_by = ["ledger_key_hash", "closed_at", "row_hash"],
        tags = ["soroban_analytics", "intermediate", "daily"]
    )
}}

/*
Model: int_transform_contract_code

Description:
------------
This intermediate model combines incremental loading and transformations for contract code data.
It processes new or updated data, calculates new fields, and performs deduplication.

Load Type: Truncate and Reload

Features:
---------
1. Uses execution_date from Airflow to determine the processing window.
2. Fetches data till the previous day from the Staging layer, one key hash per day (latest).
3. Calculates `contract_create_ts` and `contract_delete_ts` from staging data.
4. Joins the calculated timestamps with the incremental data and applies transformations.
5. Calculates a row hash using SHA256 on all relevant fields.
6. Performs deduplication based on the row hash of the fully transformed data. This step primarily detects duplicates in consecutive rows.

Usage:
------
Compile:
    dbt compile --models int_transform_contract_code

Run:
    dbt run --models int_transform_contract_code --full-refresh
    dbt run --models int_transform_contract_code
    dbt run --models int_transform_contract_code --vars '{"execution_date": "2024-10-01T00:00:00+00:00"}'
*/

-- Set the execution date (use Airflow value, fallback to dbt default if absent)
{% set execution_date = var('execution_date', dbt_airflow_macros.ts()) %}

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
            , cast('{{ execution_date }}' as timestamp) as airflow_start_ts
            -- Rank records to identify the latest entry
            , row_number() over (
                partition by ledger_key_hash, cast(closed_at as date)
                order by closed_at desc, ledger_sequence desc
            ) as row_num
        from {{ ref('stg_contract_code') }}
        where
            -- Process only completed days up to execution_date
            date(closed_at) < date('{{ execution_date }}')
    )

    , filtered_data as (
        select *
        from source_data
        where row_num = 1  -- Only consider the latest record
    )

    , derived_data as (
        select
            ledger_key_hash
            , min(case when ledger_entry_change = 0 then closed_at end) as contract_create_ts  -- Calculate contract created timestamp
            -- Calculate contract deletion timestamp
            , max(case when ledger_entry_change = 2 and deleted = true then closed_at end) as contract_delete_ts
        from source_data
        group by ledger_key_hash
    )

    , transformed_data as (
        select
            f.ledger_key_hash
            , f.contract_code_hash
            , f.last_modified_ledger
            , f.ledger_entry_change
            , f.ledger_sequence
            , f.deleted
            , f.closed_at
            , f.n_instructions
            , f.n_functions
            , f.n_globals
            , f.n_table_entries
            , f.n_types
            , f.n_data_segments
            , f.n_elem_segments
            , f.n_imports
            , f.n_exports
            , f.n_data_segment_bytes
            , d.contract_create_ts
            , d.contract_delete_ts
            , f.airflow_start_ts
            , f.batch_id
            , f.batch_run_date
            , sha256(concat(
                coalesce(f.ledger_key_hash, '')
                , coalesce(cast(f.n_instructions as string), '')
                , coalesce(cast(f.n_functions as string), '')
                , coalesce(cast(f.n_globals as string), '')
                , coalesce(cast(f.n_table_entries as string), '')
                , coalesce(cast(f.n_types as string), '')
                , coalesce(cast(f.n_data_segments as string), '')
                , coalesce(cast(f.n_elem_segments as string), '')
                , coalesce(cast(f.n_imports as string), '')
                , coalesce(cast(f.n_exports as string), '')
                , coalesce(cast(f.n_data_segment_bytes as string), '')
                , coalesce(cast(d.contract_create_ts as string), '')
                , coalesce(cast(d.contract_delete_ts as string), '')
            )) as row_hash
        from filtered_data as f
        left join derived_data as d on f.ledger_key_hash = d.ledger_key_hash
    )

    , dedup_data as (
        select
            *
            , lag(row_hash) over (partition by ledger_key_hash order by closed_at, ledger_sequence) as prev_row_hash
            , case
                when row_hash = lag(row_hash) over (partition by ledger_key_hash order by closed_at, ledger_sequence)
                    then 0  -- No change
                else 1  -- Change
            end as is_change  -- Flag records that are different from their previous record
        from transformed_data
    )

-- Select deduplicated records
select
    ledger_key_hash
    , contract_code_hash
    , last_modified_ledger
    , ledger_entry_change
    , ledger_sequence
    , contract_create_ts
    , contract_delete_ts
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
    , to_hex(row_hash) as row_hash  -- Convert the row hash to hex format to store it as a STRING field
    , batch_id
    , batch_run_date
    , airflow_start_ts
    , current_timestamp() as dw_load_ts
from dedup_data
where is_change = 1 or prev_row_hash is null
