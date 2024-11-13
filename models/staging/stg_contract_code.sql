{{ config(
    tags = ["enriched_history_operations"]
    )
}}

with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'contract_code') }}
    )

    , contract_code as (
        select
            contract_code_hash
            , contract_code_ext_v
            , last_modified_ledger
            , ledger_entry_change
            , ledger_sequence
            , ledger_key_hash
            , n_data_segment_bytes
            , n_data_segments
            , n_elem_segments
            , n_exports
            , n_functions
            , n_globals
            , n_imports
            , n_instructions
            , n_table_entries
            , n_types
            , closed_at
            , deleted
            , batch_id
            , batch_run_date
            , batch_insert_ts
            , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
        from raw_table
    )

select *
from contract_code
