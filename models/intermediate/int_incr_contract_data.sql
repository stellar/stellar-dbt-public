{{
    config(
        materialized = 'incremental',
        unique_key = ['ledger_key_hash', 'closed_at'],
        partition_by = {
            "field": "closed_at",
            "data_type": "date",
            "granularity": "month"
        },
        cluster_by = ['closed_at', 'ledger_key_hash'],
        tags = ["soroban_analytics"]
    )
}}
/*
Model: int_incr_contract_data

Description:
------------
This intermediate model handles the incremental loading of contract data from the staging layer.
It processes only new or updated data up to the previous day based on `execution_date`.

Features:
---------
1. Uses execution_date from Airflow to determine the processing window.
2. Processes new or updated records for completed days up to the previous day.
3. Selects only the latest entry per `ledger_key_hash` per day within the processing window.

Usage:
------
Compile:
    dbt compile --models int_incr_contract_data
    dbt compile --models int_incr_contract_data --vars '{"execution_date": "2024-10-25T00:00:00+00:00"}'
Run:
    dbt run --models int_incr_contract_data --full-refresh
    dbt run --models int_incr_contract_data
    dbt run --models int_incr_contract_data --vars '{"execution_date": "2024-10-25T00:00:00+00:00"}'
*/

-- Set the execution date (use Airflow value, fallback to dbt default if absent)
{% set execution_date = var('execution_date', dbt_airflow_macros.ts()) %}

with
    source_data as (
        select
            contract_id
            , ledger_key_hash
            , contract_key_type
            , contract_durability
            , last_modified_ledger
            , ledger_entry_change
            , ledger_sequence
            , asset_code
            , asset_issuer
            , asset_type
            , balance
            , balance_holder
            , deleted
            , closed_at
            , batch_insert_ts
            , batch_id
            , batch_run_date
        from {{ ref('stg_contract_data') }}
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
                partition by ledger_key_hash, cast(closed_at as date)
                order by closed_at desc, ledger_sequence desc
            ) as rn
        from source_data
    )

-- Pick only the latest change per ledger per day
select
    contract_id
    , ledger_key_hash
    , contract_key_type
    , contract_durability
    , last_modified_ledger
    , ledger_entry_change
    , ledger_sequence
    , deleted
    , closed_at
    , asset_code
    , asset_issuer
    , asset_type
    , balance
    , balance_holder
    , batch_id
    , batch_run_date
    , cast('{{ execution_date }}' as timestamp) as airflow_start_ts
    , current_timestamp() as dw_load_ts
from ranked_data
where rn = 1
