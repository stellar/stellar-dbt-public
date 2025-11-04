{% set meta_config = {
    "materialized": "incremental",
    "unique_key": "config_setting_id",
    "tags": ["current_state"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

/* Finds the latest state of network config settings.
   Ranks each record (grain: one row per config_setting_id)) using
   the last modified ledger sequence number. */

with
    current_settings as (
        select
            cfg.config_setting_id
            , cfg.contract_max_size_bytes
            , cfg.ledger_max_instructions
            , cfg.tx_max_instructions
            , cfg.fee_rate_per_instructions_increment
            , cfg.tx_memory_limit
            , cfg.ledger_max_read_ledger_entries
            , cfg.ledger_max_read_bytes
            , cfg.ledger_max_write_ledger_entries
            , cfg.ledger_max_write_bytes
            , cfg.tx_max_read_ledger_entries
            , cfg.tx_max_read_bytes
            , cfg.tx_max_write_ledger_entries
            , cfg.tx_max_write_bytes
            , cfg.fee_read_ledger_entry
            , cfg.fee_write_ledger_entry
            , cfg.fee_read_1kb
            , cfg.bucket_list_target_size_bytes
            , cfg.write_fee_1kb_bucket_list_low
            , cfg.write_fee_1kb_bucket_list_high
            , cfg.bucket_list_write_fee_growth_factor
            , cfg.fee_historical_1kb
            , cfg.tx_max_contract_events_size_bytes
            , cfg.fee_contract_events_1kb
            , cfg.ledger_max_txs_size_bytes
            , cfg.tx_max_size_bytes
            , cfg.fee_tx_size_1kb
            , cfg.contract_cost_params_cpu_insns
            , cfg.contract_cost_params_mem_bytes
            , cfg.contract_data_key_size_bytes
            , cfg.contract_data_entry_size_bytes
            , cfg.max_entry_ttl
            , cfg.min_temporary_ttl
            , cfg.min_persistent_ttl
            , cfg.auto_bump_ledgers
            , cfg.persistent_rent_rate_denominator
            , cfg.temp_rent_rate_denominator
            , cfg.max_entries_to_archive
            , cfg.bucket_list_size_window_sample_size
            , cfg.eviction_scan_size
            , cfg.starting_eviction_scan_level
            , cfg.ledger_max_tx_count
            , cfg.bucket_list_size_window
            , cfg.last_modified_ledger
            , cfg.ledger_entry_change
            , cfg.closed_at
            , cfg.deleted
            , cfg.batch_id
            , cfg.batch_run_date
            , cfg.ledger_sequence
        from {{ ref('stg_config_settings') }} as cfg
        where
            true
            and closed_at < timestamp(date('{{ var("batch_end_date") }}'))
        {% if is_incremental() %}
            and closed_at >= timestamp(date('{{ var("batch_start_date") }}'))
    {% endif %}
        qualify row_number()
            over (
                partition by cfg.config_setting_id
                order by cfg.closed_at desc
            )
        = 1
    )

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
    , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
from current_settings
