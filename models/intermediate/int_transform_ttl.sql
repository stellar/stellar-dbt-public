-- Materialized as a table for testing in lower environments. Change it to view later
{{ config(
    materialized = 'table',
    tags = ["soroban_analytics"],
    enabled = true
) }}

/*
Model: int_transform_ttl

Description:
------------
This intermediate model applies transformations to ttl data, calculates new fields,
and performs deduplication based on the transformed data.

Load Type: Truncate and Reload

Features:
---------
1. Calculates ttl_create_ts and ttl_delete_ts from staging data.
2. Joins the calculated timestamps with the incremental data and applies transformations.
3. Calculates row hash using sha256 on all relevant fields.
4. Performs deduplication based on the row hash of the fully transformed data. This step primarily detects dupes in consecutive rows.

Usage:
------
Compile :
    dbt compile --models int_transform_ttl

Run:
    dbt run --models int_transform_ttl

*/

with
    derived_data as (
        select
            key_hash
            -- Calculate contract created timestamp
            , min(case when ledger_entry_change = 0 then closed_at end)
                as ttl_create_ts
                -- Calculate contract deletion timestamp
            , max(case when ledger_entry_change = 2 and deleted = true then closed_at end) as ttl_delete_ts
        from {{ source('crypto_stellar', 'ttl') }} as ttl
        -- from {{ ref('stg_ttl') }} as cc
        group by key_hash
    )

    , transformed_data as (
        select
            ttl.key_hash
            , ttl.live_until_ledger_seq

            , dd.ttl_create_ts
            , dd.ttl_delete_ts

            , ttl.closed_at
            , ttl.ledger_sequence

            , ttl.batch_insert_ts
            , cast('{{ var("airflow_start_timestamp") }}' as timestamp) as airflow_start_ts
            , ttl.batch_id
            , ttl.batch_run_date
        from {{ ref('int_incr_ttl') }} as ttl
        left join derived_data as dd on ttl.key_hash = dd.key_hash
    )

    -- Calculate a hash for each row using sha256
    , hashed_data as (
        select
            *
            , sha256(concat(
                coalesce(cast(live_until_ledger_seq as string), '')
                , coalesce(cast(ttl_create_ts as string), '')
                , coalesce(cast(ttl_delete_ts as string), '')
            )) as row_hash
        from transformed_data
    )

    -- Identify changes between consecutive records and pick the first record if duplicates
    , dedup_data as (
        select
            *
            -- Get the hash of the previous record for each ttl_hash
            , lag(row_hash) over (partition by key_hash order by closed_at, ledger_sequence)
                as prev_row_hash
            -- Flag records that are different from their previous record
            , case
                when row_hash = lag(row_hash) over (partition by key_hash order by closed_at, ledger_sequence)
                    then 0  -- No change
                else 1  -- Change
            end as is_change
        from hashed_data
    )

-- Select deduplicated records
-- Keep records that are different from their previous record (is_change = 1)
-- OR the first record for each key_hash (prev_row_hash is null)
select
    key_hash
    , live_until_ledger_seq
    , ttl_create_ts
    , ttl_delete_ts
    , closed_at
    , ledger_sequence
    , batch_insert_ts
    , airflow_start_ts
    , batch_id
    , batch_run_date
    -- Convert the row hash to hex format to store it as a STRING field
    , to_hex(row_hash) as row_hash
    , current_timestamp() as dw_load_ts
from dedup_data
where is_change = 1 or prev_row_hash is null
