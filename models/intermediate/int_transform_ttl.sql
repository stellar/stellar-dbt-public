{{
    config(
        materialized = 'table',
        unique_key = ['key_hash', 'closed_at'],
        partition_by = {
            "field": "closed_at",
            "data_type": "date",
            "granularity": "month"
        },
        cluster_by = ["key_hash", "closed_at", "row_hash"],
        tags = ["soroban_analytics", "intermediate", "daily"]
    )
}}

/*
Model: int_transform_ttl

Description:
------------
This intermediate model combines incremental loading and transformations for ledger TTL data, calculates new fields,
and performs deduplication based on the transformed data.

Load Type: Truncate and Reload

Features:
---------
1. Uses execution_date from Airflow to determine the processing window.
2. Fetches data till the previous day from the Staging layer, one key hash per day (latest).
3. Calculates `ttl_create_ts` and `ttl_delete_ts` from staging data.
4. Joins the calculated timestamps with the incremental data and applies transformations.
5. Calculates a row hash using SHA256 on all relevant fields.
6. Performs deduplication based on the row hash of the fully transformed data. This step primarily detects duplicates in consecutive rows.

Usage:
------
Compile:
    dbt compile --models int_transform_ttl

Run:
    dbt run --models int_transform_ttl --full-refresh
    dbt run --models int_transform_ttl
    dbt run --models int_transform_ttl --vars '{"execution_date": "2024-10-25T00:00:00+00:00"}'
*/

-- Set the execution date (use Airflow value, fallback to dbt default if absent)
{% set execution_date = var('execution_date', dbt_airflow_macros.ts()) %}

with
    -- Extract data from the staging table and rank records based on key_hash and closed_at
    source_data as (
        select
            key_hash
            , live_until_ledger_seq
            , last_modified_ledger
            , ledger_entry_change
            , ledger_sequence
            , deleted
            , closed_at
            , batch_insert_ts
            , batch_id
            , batch_run_date
            , cast('{{ execution_date }}' as timestamp) as airflow_start_ts
            -- Rank records to identify the latest entry
            , row_number() over (
                partition by key_hash, cast(closed_at as date)
                order by closed_at desc, ledger_sequence desc
            ) as row_num
        from {{ ref('stg_ttl') }}
        where
            -- Process only completed days up to execution_date
            date(closed_at) < date('{{ execution_date }}')
    )

    -- Filter to retain only the latest record for each key_hash
    , filtered_data as (
        select *
        from source_data
        where row_num = 1  -- Only consider the latest record
    )

    -- Calculate TTL create and delete timestamps
    , derived_data as (
        select
            key_hash
            , min(case when ledger_entry_change = 0 then closed_at end) as ttl_create_ts
            , max(case when ledger_entry_change = 2 and deleted = true then closed_at end) as ttl_delete_ts
        from source_data
        group by key_hash
    )

    -- Prepare transformed data with additional fields
    , transformed_data as (
        select
            ttl.key_hash
            , ttl.live_until_ledger_seq
            , derived.ttl_create_ts
            , derived.ttl_delete_ts
            , ttl.closed_at
            , ttl.ledger_sequence
            , ttl.batch_id
            , ttl.batch_run_date
            , ttl.airflow_start_ts
            , sha256(concat(
                coalesce(cast(ttl.live_until_ledger_seq as string), '')
                , coalesce(cast(derived.ttl_create_ts as string), '')
                , coalesce(cast(derived.ttl_delete_ts as string), '')
            )) as row_hash
        from filtered_data as ttl
        left join derived_data as derived on ttl.key_hash = derived.key_hash
    )

    -- Identify changes between consecutive records and pick the first record if duplicates
    , dedup_data as (
        select
            *
            , lag(row_hash) over (partition by key_hash order by closed_at, ledger_sequence) as prev_row_hash
            , case
                when row_hash = lag(row_hash) over (partition by key_hash order by closed_at, ledger_sequence)
                    then 0  -- No change
                else 1  -- Change
            end as is_change  -- Flag records that are different from their previous record
        from transformed_data
    )

-- Select deduplicated records
select
    key_hash
    , live_until_ledger_seq
    , ttl_create_ts
    , ttl_delete_ts
    , closed_at
    , ledger_sequence
    , to_hex(row_hash) as row_hash  -- Convert the row hash to hex format to store it as a STRING field
    , batch_id
    , batch_run_date
    , airflow_start_ts
    , current_timestamp() as dw_load_ts
from dedup_data
where is_change = 1 or prev_row_hash is null
