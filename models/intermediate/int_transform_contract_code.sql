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
This intermediate model applies transformations to the contract code, calculates new fields,
and performs deduplication based on the transformed data.

Load Type: Full Truncate and Reload

Features:
---------
1. Calculates contract_create_ts and contract_delete_ts from staging data.
2. Joins the calculated timestamps with the incremental data and applies transformations.
3. Standardizes data by applying default values as well as type casting as applicable.
4. Calculates row hash using sha256 on all relevant CDC fields.
5. Performs deduplication based on the row hash of the fully transformed data. This step primarily detects dupes in consecutive rows.

Usage:
------
Compile:
    dbt compile --models int_transform_contract_code

Run:
    dbt run --models int_transform_contract_code --full-refresh
    dbt run --models int_transform_contract_code
*/

with
    derived_data as (
        select
            contract_code_hash
            , min(case when ledger_entry_change = 0 then closed_at end) as contract_create_ts  -- Calculate contract created timestamp
            -- Calculate contract deletion timestamp
            , max(case when ledger_entry_change = 2 and deleted = true then closed_at end) as contract_delete_ts
        from {{ ref('stg_contract_code') }}
        group by contract_code_hash
    )

    , source_data as (
        select
            int.contract_code_hash
            , int.ledger_key_hash
            , int.n_instructions
            , int.n_functions
            , int.n_globals
            , int.n_table_entries
            , int.n_types
            , int.n_data_segments
            , int.n_elem_segments
            , int.n_imports
            , int.n_exports
            , int.n_data_segment_bytes
            , derived.contract_create_ts
            , derived.contract_delete_ts
            , int.closed_at
            , int.ledger_sequence
            , int.airflow_start_ts
            , int.batch_id
            , int.batch_run_date
        from {{ ref('int_incr_contract_code') }} as int
        left join derived_data as derived on int.contract_code_hash = derived.contract_code_hash
    )

    -- Calculate a hash for each row using sha256
    , hashed_data as (
        select
            *
            , sha256(concat(
                coalesce(ledger_key_hash, '')
                , coalesce(cast(n_instructions as string), '')
                , coalesce(cast(n_functions as string), '')
                , coalesce(cast(n_globals as string), '')
                , coalesce(cast(n_table_entries as string), '')
                , coalesce(cast(n_types as string), '')
                , coalesce(cast(n_data_segments as string), '')
                , coalesce(cast(n_elem_segments as string), '')
                , coalesce(cast(n_imports as string), '')
                , coalesce(cast(n_exports as string), '')
                , coalesce(cast(n_data_segment_bytes as string), '')
                , coalesce(cast(contract_create_ts as string), '')
                , coalesce(cast(contract_delete_ts as string), '')
            )) as row_hash
        from source_data
    )

    -- Identify changes between consecutive records and pick the first record if duplicates
    , dedup_data as (
        select
            *
            -- Get the hash of the previous record for each contract_code_hash
            , lag(row_hash) over (partition by contract_code_hash order by closed_at, ledger_sequence) as prev_row_hash
            , case
                when row_hash = lag(row_hash) over (partition by contract_code_hash order by closed_at, ledger_sequence)
                    then 0  -- No change
                else 1  -- Change
            end as is_change  -- Flag records that are different from their previous record
        from hashed_data
    )

-- Keep records that are different from their previous record (is_change = 1)
-- OR the first record for each ledger_key_hash (prev_row_hash is null)
select
    contract_code_hash
    , ledger_key_hash
    , ledger_sequence
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
    , to_hex(row_hash) as row_hash  -- Convert the row hash to hex format to store it as a STRING field
    , batch_id
    , batch_run_date
    , airflow_start_ts
    , current_timestamp() as dw_load_ts
from dedup_data
where is_change = 1 or prev_row_hash is null
