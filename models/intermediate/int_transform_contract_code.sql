-- Materialized as a table for testing in lower environments. Change it to view later
{{ config(
    materialized = 'table',
    tags = ["soroban_analytics"],
    enabled = true
) }}

/*
Model: int_transform_contract_code

Description:
------------
This intermediate model applies transformations to the contract code, calculates new fields,
and performs deduplication based on the transformed data.

Load Type: Truncate and Reload

Features:
---------
1. Calculates contract_create_ts and contract_delete_ts from staging data.
2. Joins the calculated timestamps with the incremental data and applies transformations.
3. Trims spaces on string fields and standardizes blank values as NULL.
4. Calculates row hash using sha256 on all relevant fields.
5. Performs deduplication based on the row hash of the fully transformed data. This step primarily detects dupes in consecutive rows.

Usage:
------
Compile :
    dbt compile --models int_transform_contract_code

Run:
    dbt run --models int_transform_contract_code

*/

with derived_data as (
    select
        contract_code_hash,
        -- Calculate contract created timestamp
        min(case when ledger_entry_change = 0 then closed_at end) as contract_create_ts,
        -- Calculate contract deletion timestamp
        max(case when ledger_entry_change = 2 and deleted = true then closed_at end) as contract_delete_ts
    from {{ source('crypto_stellar', 'contract_code') }}
    -- from {{ ref('stg_contract_code') }} as cc
    group by contract_code_hash
),

transformed_data as (
    select
        cc.contract_code_hash,
        cc.ledger_key_hash,

        cc.n_instructions,
        cc.n_functions,
        cc.n_globals,
        cc.n_table_entries,
        cc.n_types,
        cc.n_data_segments,
        cc.n_elem_segments,
        cc.n_imports,
        cc.n_exports,
        cc.n_data_segment_bytes,

        dd.contract_create_ts,
        dd.contract_delete_ts,

        cc.closed_at,
        cc.ledger_sequence,

        cc.batch_insert_ts,
        cast('{{ var("airflow_start_timestamp") }}' as TIMESTAMP) as airflow_start_ts,
        cc.batch_id,
        cc.batch_run_date
    from {{ ref('int_incr_contract_code') }} cc
    left join derived_data dd on cc.contract_code_hash = dd.contract_code_hash
),

-- Calculate a hash for each row using sha256
hashed_data as (
    select
        *,
        sha256(concat(
            coalesce(ledger_key_hash, ''),
            coalesce(cast(n_instructions as string), ''),
            coalesce(cast(n_functions as string), ''),
            coalesce(cast(n_globals as string), ''),
            coalesce(cast(n_table_entries as string), ''),
            coalesce(cast(n_types as string), ''),
            coalesce(cast(n_data_segments as string), ''),
            coalesce(cast(n_elem_segments as string), ''),
            coalesce(cast(n_imports as string), ''),
            coalesce(cast(n_exports as string), ''),
            coalesce(cast(n_data_segment_bytes as string), ''),
            coalesce(cast(contract_create_ts as string), ''),
            coalesce(cast(contract_delete_ts as string), '')
        )) as row_hash
    from transformed_data
),

-- Identify changes between consecutive records and pick the first record if duplicates
dedup_data as (
    select
        *,
        -- Get the hash of the previous record for each contract_code_hash
        lag(row_hash) over (partition by contract_code_hash order by closed_at, ledger_sequence) as prev_row_hash,
        -- Flag records that are different from their previous record
        case
            when row_hash = lag(row_hash) over (partition by contract_code_hash order by closed_at, ledger_sequence)
            then 0  -- No change
            else 1  -- Change
        end as is_change
    from hashed_data
)

-- Select deduplicated records
-- Keep records that are different from their previous record (is_change = 1)
-- OR the first record for each ledger_key_hash (prev_row_hash is null)
select
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
    ledger_sequence,
    batch_insert_ts,
    airflow_start_ts,
    batch_id,
    batch_run_date,
    -- Convert the row hash to hex format to store it as a STRING field
    to_hex(row_hash) as row_hash,
    current_timestamp() as dw_load_ts
from dedup_data
where is_change = 1 or prev_row_hash is null
