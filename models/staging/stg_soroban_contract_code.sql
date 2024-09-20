{{ config(
    materialized = 'view',
    tags = ["soroban_analytics"],
    enabled = true,
    tests = {
        'unique': {
            'column_name': 'ledger_key_hash'
        },
        'not_null': {
            'column_name': 'ledger_key_hash'
        }
    }
) }}

{% set target_table_query %}
    SELECT COUNT(*) AS tgt_row_count FROM {{ ref('contract_details_hist') }}
{% endset %}

{% set results = run_query(target_table_query) %}

{% if execute %}
    {% set is_empty_target_table = (results.columns[0].values()[0] == 0) %}
{% else %}
    {% set is_empty_target_table = false %}
{% endif %}

with
    contract_code as (
        -- Pull data from contract_data
        -- Depending on whether the target table is empty or based on recovery logic

        select
            cc.contract_code_hash
            , cc.last_modified_ledger
            , cc.ledger_entry_change
            , cc.ledger_sequence
            , cc.ledger_key_hash
            , cc.n_instructions
            , cc.n_functions
            , cc.n_globals
            , cc.n_table_entries
            , cc.n_types
            , cc.n_data_segments
            , cc.n_elem_segments
            , cc.n_imports
            , cc.n_exports
            , cc.n_data_segment_bytes
            , cc.deleted
            , cc.closed_at
            , cc.batch_insert_ts
            , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
            , cc.batch_id
            , cc.batch_run_date
            , row_number() over (partition by cc.ledger_key_hash order by cc.closed_at desc) as row_num
        from
            {{ source('crypto_stellar', 'contract_code') }} as cc

        -- If the target table is empty, pull all data for first-time run
        {% if is_empty_target_table %}
        -- No WHERE condition here, as we want to pull all records

        {% elif var('recovery', 'False') == 'True' %}
        -- If recovery is enabled, apply the appropriate recovery filter

        -- Single day recovery
        {% if var('recovery_type', 'SingleDay') == 'SingleDay' %}
            WHERE DATE(cc.closed_at) = '{{ var("recovery_date") }}'

        -- Date Range recovery
        {% elif var('recovery_type', 'Range') == 'Range' %}
            WHERE DATE(cc.closed_at) BETWEEN '{{ var("recovery_start_day") }}' AND '{{ var("recovery_end_day") }}'

        -- Full recovery
        {% elif var('recovery_type', 'Full') == 'Full' %}
            -- No WHERE condition for full recovery, as we want all data
        {% endif %}

    -- Regular cadence filtering (2-hour forward window, 4-hour backward window)
    {% else %}
        WHERE
            timestamp(cc.closed_at) < timestamp_add(timestamp('{{ var("airflow_start_timestamp") }}'), interval 2 hour)
            AND timestamp(cc.closed_at) >= timestamp_sub(timestamp('{{ var("airflow_start_timestamp") }}'), interval 4 hour)
    {% endif %}
    )

    , ttl_data as (
        select
            ttl.key_hash
            , ttl.closed_at as ttl_closed_at
            , ttl.live_until_ledger_seq
            , ttl.deleted as ttl_deleted
            , row_number() over (partition by ttl.key_hash order by ttl.closed_at desc) as row_num
        from
            {{ source('crypto_stellar', 'ttl') }} as ttl

        -- If the target table is empty, pull all data for first-time run
        {% if is_empty_target_table %}
        -- No WHERE condition here, as we want to pull all records

        {% elif var('recovery', 'False') == 'True' %}
        -- If recovery is enabled, apply the appropriate recovery filter

        -- Single day recovery
        {% if var('recovery_type', 'SingleDay') == 'SingleDay' %}
            WHERE DATE(ttl.closed_at) = '{{ var("recovery_date") }}'

        -- Range recovery
        {% elif var('recovery_type', 'Range') == 'Range' %}
            WHERE DATE(ttl.closed_at) BETWEEN '{{ var("recovery_start_day") }}' AND '{{ var("recovery_end_day") }}'

        -- Full recovery
        {% elif var('recovery_type', 'Full') == 'Full' %}
            -- No WHERE condition for full recovery, as we want all data
        {% endif %}

    -- Regular cadence filtering (2-hour forward window, 4-hour backward window)
    {% else %}
        WHERE
            timestamp(ttl.closed_at) < timestamp_add(timestamp('{{ var("airflow_start_timestamp") }}'), interval 2 hour)
            AND timestamp(ttl.closed_at) >= timestamp_sub(timestamp('{{ var("airflow_start_timestamp") }}'), interval 4 hour)
    {% endif %}
    )

    , source_data as (
        select
            cc.contract_code_hash
            , cc.last_modified_ledger
            , cc.ledger_entry_change
            , cc.ledger_sequence
            , cc.ledger_key_hash
            , cc.n_instructions
            , cc.n_functions
            , cc.n_globals
            , cc.n_table_entries
            , cc.n_types
            , cc.n_data_segments
            , cc.n_elem_segments
            , cc.n_imports
            , cc.n_exports
            , cc.n_data_segment_bytes
            , cc.deleted
            , cc.closed_at
            , ttl.key_hash
            , ttl.ttl_closed_at
            , ttl.live_until_ledger_seq
            , ttl.ttl_deleted
            , cc.batch_insert_ts
            , cc.airflow_start_ts
            , cc.batch_id
            , cc.batch_run_date
        from
            contract_code as cc
        left join
            ttl_data as ttl
            on
            cc.ledger_key_hash = ttl.key_hash
        where
            cc.row_num = 1  -- Only the latest record per ledger_key_hash from contract_code
            and (ttl.row_num = 1 or ttl.row_num is null)  -- Only the latest record from ttl, if available
    )

select
    contract_code_hash
    , last_modified_ledger
    , ledger_entry_change
    , ledger_sequence
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
    , deleted
    , closed_at
    , key_hash
    , ttl_closed_at
    , live_until_ledger_seq
    , ttl_deleted
    , batch_insert_ts
    , airflow_start_ts
    , batch_id
    , batch_run_date
    , current_timestamp() as dw_load_ts
from source_data
order by
    ledger_key_hash, closed_at
