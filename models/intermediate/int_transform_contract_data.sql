{{
    config(
        materialized = 'table',
        unique_key = ['ledger_key_hash', 'closed_at'],
        partition_by = {
            "field": "closed_at",
            "data_type": "date",
            "granularity": "month"
        },
        cluster_by = ["ledger_key_hash", "closed_at", "row_hash"],
        tags = ["soroban_analytics"]
    )
}}

/*
Model: int_transform_contract_data

Description:
------------
This intermediate model applies transformations to the contract data, calculates new fields,
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
Compile:
    dbt compile --models int_transform_contract_data

Run:
    dbt run --models int_transform_contract_data --full-refresh
    dbt run --models int_transform_contract_data
*/

with
    derived_data as (
        select
            contract_id
            -- Calculate contract created timestamp
            , min(case when ledger_entry_change = 0 and contract_key_type = 'ScValTypeScvLedgerKeyContractInstance' then closed_at end)
                as contract_create_ts
            -- Calculate contract deletion timestamp
            , max(case when ledger_entry_change = 2 and deleted = true then closed_at end) as contract_delete_ts
        from {{ ref('stg_contract_data') }}
        group by contract_id
    )

    , transformed_data as (
        select
            incr.contract_id
            , incr.ledger_key_hash
            , case
                when nullif(trim(incr.contract_durability), '') = 'ContractDataDurabilityPersistent' then 'persistent'
                when nullif(trim(incr.contract_durability), '') = 'ContractDataDurabilityTemporary' then 'temporary'
                else nullif(trim(incr.contract_durability), '')
            end as contract_durability
            , nullif(trim(incr.asset_code), '') as asset_code
            , nullif(trim(incr.asset_issuer), '') as asset_issuer
            , nullif(trim(incr.asset_type), '') as asset_type
            , cast(round(safe_cast(incr.balance as float64) / pow(10, 7), 5) as numeric) as balance
            , nullif(trim(incr.balance_holder), '') as balance_holder
            , derived.contract_create_ts
            , derived.contract_delete_ts
            , incr.closed_at
            , incr.ledger_sequence
            , incr.airflow_start_ts
            , incr.batch_id
            , incr.batch_run_date
        from {{ ref('int_incr_contract_data') }} as incr
        left join derived_data as derived on incr.contract_id = derived.contract_id
    )

    -- Calculate a hash for each row using sha256
    , hashed_data as (
        select
            *
            , sha256(concat(
                coalesce(ledger_key_hash, '')
                , coalesce(contract_durability, '')
                , coalesce(asset_code, '')
                , coalesce(asset_issuer, '')
                , coalesce(asset_type, '')
                , coalesce(cast(balance as string), '')
                , coalesce(balance_holder, '')
                , coalesce(cast(contract_create_ts as string), '')
                , coalesce(cast(contract_delete_ts as string), '')
            )) as row_hash
        from transformed_data
    )

    -- Identify changes between consecutive records and pick the first record if duplicates
    , dedup_data as (
        select
            *
            -- Get the hash of the previous record for each contract_id
            , lag(row_hash) over (partition by contract_id order by closed_at, ledger_sequence) as prev_row_hash
            , case
                when row_hash = lag(row_hash) over (partition by contract_id order by closed_at, ledger_sequence)
                    then 0  -- No change
                else 1  -- Change
            end as is_change  -- Flag records that are different from their previous record
        from hashed_data
    )

-- Select deduplicated records
-- Keep records that are different from their previous record (is_change = 1)
-- OR the first record for each ledger_key_hash (prev_row_hash is null)
select
    contract_id
    , ledger_key_hash
    , contract_durability
    , ledger_sequence
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
    , to_hex(row_hash) as row_hash  -- Convert the row hash to hex format to store it as a STRING field
    , current_timestamp() as dw_load_ts
from dedup_data
where is_change = 1 or prev_row_hash is null
