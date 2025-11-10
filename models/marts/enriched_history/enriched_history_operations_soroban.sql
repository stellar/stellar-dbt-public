{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["op_id"],
    "cluster_by": ["ledger_sequence", "transaction_id", "op_type"],
    "partition_by": {
        "field": "closed_at"
        , "data_type": "timestamp"
        , "granularity": "month"},
    "tags": ["enriched_history_operations"],
    "incremental_predicates":["DBT_INTERNAL_DEST.closed_at >= timestamp_sub(timestamp(date('" ~ var('batch_start_date') ~ "')), interval 1 day)"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

with
    eho_soroban as (
        select
            enriched.op_id
            , enriched.op_source_account
            , enriched.op_source_account_muxed
            , enriched.transaction_id
            , enriched.type as op_type
            , enriched.type_string
            -- expanded operations details fields
            , enriched.from
            , enriched.asset_balance_changes
            , enriched.parameters
            , enriched.parameters_decoded
            , enriched.function
            , enriched.address
            , enriched.soroban_operation_type
            , enriched.extend_to
            , enriched.contract_id
            , enriched.contract_code_hash
            , enriched.operation_result_code
            , enriched.operation_trace_code
            -- transaction fields
            , enriched.transaction_hash
            , enriched.ledger_sequence
            , enriched.txn_account
            , enriched.account_sequence
            , enriched.max_fee
            , enriched.txn_operation_count
            , enriched.txn_created_at
            , enriched.memo_type
            , enriched.memo
            , enriched.time_bounds
            , enriched.successful
            , enriched.fee_charged
            , enriched.fee_account
            , enriched.new_max_fee
            , enriched.account_muxed
            , enriched.fee_account_muxed
            --new protocol 19 fields for transaction preconditions
            , enriched.ledger_bounds
            , enriched.min_account_sequence
            , enriched.min_account_sequence_age
            , enriched.min_account_sequence_ledger_gap
            , enriched.extra_signers
            , enriched.resource_fee
            , enriched.soroban_resources_instructions
            , enriched.soroban_resources_read_bytes
            , enriched.soroban_resources_write_bytes
            , enriched.transaction_result_code
            , enriched.inclusion_fee_bid
            , enriched.inclusion_fee_charged
            , enriched.resource_fee_refund
            -- ledger fields
            , enriched.ledger_hash
            , enriched.previous_ledger_hash
            , enriched.transaction_count
            , enriched.ledger_operation_count
            , enriched.closed_at
            , enriched.ledger_id
            , enriched.total_coins
            , enriched.fee_pool
            , enriched.base_fee
            , enriched.base_reserve
            , enriched.max_tx_set_size
            , enriched.protocol_version
            , enriched.successful_transaction_count
            , enriched.failed_transaction_count
            -- json blob for operation details
            , enriched.details_json
            -- general fields
            , enriched.batch_id
            , enriched.batch_run_date
            -- ledger header details
            , enriched.soroban_fee_write_1kb
            , enriched.node_id
            , enriched.signature
            , enriched.total_byte_size_of_bucket_list
            -- soroban fee details
            , enriched.non_refundable_resource_fee_charged
            , enriched.refundable_resource_fee_charged
            , enriched.rent_fee_charged
            , enriched.tx_signers
            , enriched.refundable_fee
        from {{ ref('enriched_history_operations') }} as enriched
        where
            enriched.type in (24, 25, 26)
            -- Need to add/subtract one day to the window boundaries
            -- because this model runs at 30 min increments.
            -- Without the additional date buffering the following would occur
            -- * batch_start_date == '2025-01-01 01:00:00' --> '2025-01-01'
            -- * batch_end_date == '2025-01-01 01:30:00' --> '2025-01-01'
            -- * '2025-01-01 <= closed_at < '2025-01-01' would never have any data to processes
            and closed_at < timestamp(date_add(date('{{ var("batch_end_date") }}'), interval 1 day))
        {% if is_incremental() %}
                -- The extra day date_sub is useful in the case the first scheduled run for a day is skipped
                -- because the DAG is configured with catchup=false
                and closed_at >= timestamp(date_sub(date('{{ var("batch_start_date") }}'), interval 1 day))
            {% endif %}
    )

select
    *
    , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
from eho_soroban
