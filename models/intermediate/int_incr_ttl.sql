{{
    config(
        materialized = 'incremental',
        unique_key = ['key_hash', 'closed_at'],
        partition_by = {
            "field": "closed_at",
            "data_type": "date",
            "granularity": "month"
        },
        cluster_by = ['closed_at', 'key_hash'],
        tags = ["soroban_analytics"]
    )
}}
/*
Model: int_incr_ttl

Description:
------------
This intermediate model handles the incremental loading of ledger time-to-live (TTL)
data from the staging layer. It processes only new or updated data up to the previous day based on `execution_date`.

Features:
---------
1. Uses execution_date from Airflow to determine the processing window.
2. Processes new or updated records for completed days up to the previous day.
3. Selects only the latest entry per `key_hash` per day within the processing window.

Usage:
------
Compile:
    dbt compile --models int_incr_ttl
    dbt compile --models int_incr_ttl --vars '{"execution_date": "2024-10-25T00:00:00+00:00"}'
Run:
    dbt run --models int_incr_ttl --full-refresh
    dbt run --models int_incr_ttl
    dbt run --models int_incr_ttl --vars '{"execution_date": "2024-10-25T00:00:00+00:00"}'
*/

-- Set the execution date (use Airflow value, fallback to dbt default if absent)
{% set execution_date = var('execution_date', dbt_airflow_macros.ts()) %}

with
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
        from {{ ref('stg_ttl') }}
        where
        -- Process only completed days up to execution_date for incremental loads
            date(closed_at) < date('{{ execution_date }}')

            -- Process records inserted since the last load (incremental only)
            {% if is_incremental() %}
                and date(closed_at) >= (select coalesce(max(date(closed_at)), '2000-01-01') from {{ this }})
            {% endif %}
    )
    , ranked_data as (
        select
            *
            , row_number() over (
                partition by key_hash, cast(closed_at as date)
                order by closed_at desc, ledger_sequence desc
            ) as rn
        from source_data
    )

-- Pick only the latest change per key_hash per day
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
    , current_timestamp() as dw_load_ts
from ranked_data
where rn = 1
