{{ config()
}}

with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'config_settings') }}
    )

    , config_settings as (
        select
            config_setting_id
            , contract_max_size_bytes
            , ledger_max_instructions
            , tx_max_instructions
            , fee_rate_per_instructions_increment
            , tx_memory_limit
            , ledger_max_read_ledger_entries
            , ledger_max_read_bytes
            , ledger_max_write_ledger_entries
            , ledger_max_write_bytes
            , tx_max_read_ledger_entries
            , tx_max_read_bytes
            , tx_max_write_ledger_entries
            , tx_max_write_bytes
            , fee_read_ledger_entry
            , fee_write_ledger_entry
            , fee_read_1kb
            , bucket_list_target_size_bytes
            , write_fee_1kb_bucket_list_low
            , write_fee_1kb_bucket_list_high
            , bucket_list_write_fee_growth_factor
            , fee_historical_1kb
            , tx_max_contract_events_size_bytes
            , fee_contract_events_1kb
            , ledger_max_txs_size_bytes
            , tx_max_size_bytes
            , fee_tx_size_1kb
            , contract_cost_params_cpu_insns
            , contract_cost_params_mem_bytes
            , contract_data_key_size_bytes
            , contract_data_entry_size_bytes
            , max_entry_ttl
            , min_temporary_ttl
            , min_persistent_ttl
            , auto_bump_ledgers
            , persistent_rent_rate_denominator
            , temp_rent_rate_denominator
            , max_entries_to_archive
            , bucket_list_size_window_sample_size
            , eviction_scan_size
            , starting_eviction_scan_level
            , ledger_max_tx_count
            , bucket_list_size_window
            , last_modified_ledger
            , ledger_entry_change
            , ledger_sequence
            , closed_at
            , deleted
            , batch_id
            , batch_run_date
            , batch_insert_ts
            , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
        from raw_table
    )

select *
from config_settings
