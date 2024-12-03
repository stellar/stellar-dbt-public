{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["op_id"],
    "cluster_by": ["ledger_sequence","transaction_id","op_account_id","type"],
    "partition_by": {
        "field": "closed_at"
        , "data_type": "timestamp"
        , "granularity": "month"},
    "tags": ["enriched_history_operations"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

with
    history_ledgers as (
        select
            sequence
            , ledger_hash
            , previous_ledger_hash
            , transaction_count
            , ledger_operation_count
            , closed_at
            , ledger_id
            , total_coins
            , fee_pool
            , base_fee
            , base_reserve
            , max_tx_set_size
            , protocol_version
            , successful_transaction_count
            , failed_transaction_count
            , soroban_fee_write_1kb
            , node_id
            , signature
            , total_byte_size_of_bucket_list
            , batch_id
            , batch_run_date
        from {{ ref('stg_history_ledgers') }}
        where
            cast(batch_run_date as date) < date_add(date('{{ dbt_airflow_macros.ts(timezone=none) }}'), interval 2 day)
            and date(closed_at) < date_add(date('{{ dbt_airflow_macros.ts(timezone=none) }}'), interval 1 day)
            {% if is_incremental() %}
                and cast(batch_run_date as date) >= date_sub(date('{{ dbt_airflow_macros.ts(timezone=none) }}'), interval 1 day)
                and date(closed_at) >= date_sub(date('{{ dbt_airflow_macros.ts(timezone=none) }}'), interval 1 day)
            {% endif %}
    )

    , history_transactions as (
        select
            transaction_id
            , transaction_hash
            , ledger_sequence
            , txn_account
            , account_sequence
            , max_fee
            , txn_operation_count
            , txn_created_at
            , memo_type
            , memo
            , time_bounds
            , successful
            , fee_charged
            , fee_account
            , new_max_fee
            , account_muxed
            , fee_account_muxed
            , ledger_bounds
            , min_account_sequence
            , min_account_sequence_age
            , min_account_sequence_ledger_gap
            , extra_signers
            , batch_id
            , batch_run_date
            , resource_fee
            , soroban_resources_instructions
            , soroban_resources_read_bytes
            , soroban_resources_write_bytes
            , transaction_result_code
            , inclusion_fee_bid
            , inclusion_fee_charged
            , resource_fee_refund
            , non_refundable_resource_fee_charged
            , refundable_resource_fee_charged
            , rent_fee_charged
            , tx_signers
            , refundable_fee
        from {{ ref('stg_history_transactions') }}
        where
            cast(batch_run_date as date) < date_add(date('{{ dbt_airflow_macros.ts(timezone=none) }}'), interval 2 day)
            and date(closed_at) < date_add(date('{{ dbt_airflow_macros.ts(timezone=none) }}'), interval 1 day)
            {% if is_incremental() %}
                and cast(batch_run_date as date) >= date_sub(date('{{ dbt_airflow_macros.ts(timezone=none) }}'), interval 1 day)
                and date(closed_at) >= date_sub(date('{{ dbt_airflow_macros.ts(timezone=none) }}'), interval 1 day)
            {% endif %}
    )

    , history_operations as (
        select
            account
            , op_account_muxed
            , op_account_muxed_id
            , op_account_id
            , amount
            , asset
            , asset_code
            , asset_issuer
            , asset_type
            , authorize
            , coalesce(balance_id, claimable_balance_id) as balance_id
            , claimant
            , claimant_muxed
            , claimant_muxed_id
            , claimants
            , data_account_id
            , data_name
            , buying_asset_code
            , buying_asset_issuer
            , buying_asset_type
            , `from`
            , from_muxed
            , from_muxed_id
            , funder
            , funder_muxed
            , funder_muxed_id
            , high_threshold
            , home_domain
            , inflation_dest
            , `into`
            , into_muxed
            , into_muxed_id
            , `limit`
            , low_threshold
            , master_key_weight
            , med_threshold
            , name
            , offer_id
            , path
            , price
            , price_r
            , selling_asset_code
            , selling_asset_issuer
            , selling_asset_type
            , set_flags
            , set_flags_s
            , signer_account_id
            , signer_key
            , signer_weight
            , source_amount
            , source_asset_code
            , source_asset_issuer
            , source_asset_type
            , source_max
            , starting_balance
            , `to`
            , to_muxed
            , to_muxed_id
            , trustee
            , trustee_muxed
            , trustee_muxed_id
            , trustor
            , trustor_muxed
            , trustor_muxed_id
            , trustline_account_id
            , trustline_asset
            , value
            , clear_flags
            , clear_flags_s
            , destination_min
            , bump_to
            , sponsor
            , sponsored_id
            , begin_sponsor
            , begin_sponsor_muxed
            , begin_sponsor_muxed_id
            , authorize_to_maintain_liabilities
            , clawback_enabled
            , liquidity_pool_id
            , reserve_a_asset_type
            , reserve_a_asset_code
            , reserve_a_asset_issuer
            , reserve_a_max_amount
            , reserve_a_deposit_amount
            , reserve_b_asset_type
            , reserve_b_asset_code
            , reserve_b_asset_issuer
            , reserve_b_max_amount
            , reserve_b_deposit_amount
            , min_price
            , min_price_r
            , max_price
            , max_price_r
            , shares_received
            , reserve_a_min_amount
            , reserve_b_min_amount
            , shares
            , reserve_a_withdraw_amount
            , reserve_b_withdraw_amount
            , op_id
            , op_source_account
            , op_source_account_muxed
            , transaction_id
            , type
            , type_string
            , batch_id
            , batch_run_date
            , asset_balance_changes
            , parameters
            , parameters_decoded
            , function
            , address
            , soroban_operation_type
            , extend_to
            , contract_id
            , contract_code_hash
            , operation_result_code
            , operation_trace_code
            , details_json
        from {{ ref('stg_history_operations') }}
        where
            cast(batch_run_date as date) < date_add(date('{{ dbt_airflow_macros.ts(timezone=none) }}'), interval 2 day)
            and date(closed_at) < date_add(date('{{ dbt_airflow_macros.ts(timezone=none) }}'), interval 1 day)
            {% if is_incremental() %}
                and cast(batch_run_date as date) >= date_sub(date('{{ dbt_airflow_macros.ts(timezone=none) }}'), interval 1 day)
                and date(closed_at) >= date_sub(date('{{ dbt_airflow_macros.ts(timezone=none) }}'), interval 1 day)
            {% endif %}

    )

    , enriched_operations as (
        select
            hist_ops.op_id
            , hist_ops.op_source_account
            , hist_ops.op_source_account_muxed
            , hist_ops.transaction_id
            , hist_ops.type
            , hist_ops.type_string
            -- expanded operations details fields
            , hist_ops.account
            , hist_ops.op_account_muxed
            , hist_ops.op_account_id
            , hist_ops.op_account_muxed_id
            , hist_ops.amount
            , hist_ops.asset
            , hist_ops.asset_code
            , hist_ops.asset_issuer
            , hist_ops.asset_type
            , hist_ops.authorize
            , hist_ops.balance_id
            , hist_ops.claimant
            , hist_ops.claimant_muxed
            , hist_ops.claimant_muxed_id
            , hist_ops.claimants
            , hist_ops.data_account_id
            , hist_ops.data_name
            , hist_ops.buying_asset_code
            , hist_ops.buying_asset_issuer
            , hist_ops.buying_asset_type
            , hist_ops.from
            , hist_ops.from_muxed
            , hist_ops.from_muxed_id
            , hist_ops.funder
            , hist_ops.funder_muxed
            , hist_ops.funder_muxed_id
            , hist_ops.high_threshold
            , hist_ops.home_domain
            , hist_ops.inflation_dest
            , hist_ops.into
            , hist_ops.into_muxed
            , hist_ops.into_muxed_id
            , hist_ops.limit
            , hist_ops.low_threshold
            , hist_ops.master_key_weight
            , hist_ops.med_threshold
            , hist_ops.name
            , hist_ops.offer_id
            , hist_ops.path
            , hist_ops.price
            , hist_ops.price_r.d
            , hist_ops.price_r.n
            , hist_ops.selling_asset_code
            , hist_ops.selling_asset_issuer
            , hist_ops.selling_asset_type
            , hist_ops.set_flags
            , hist_ops.set_flags_s
            , hist_ops.signer_account_id
            , hist_ops.signer_key
            , hist_ops.signer_weight
            , hist_ops.source_amount
            , hist_ops.source_asset_code
            , hist_ops.source_asset_issuer
            , hist_ops.source_asset_type
            , hist_ops.source_max
            , hist_ops.starting_balance
            , hist_ops.to
            , hist_ops.to_muxed
            , hist_ops.to_muxed_id
            , hist_ops.trustee
            , hist_ops.trustee_muxed
            , hist_ops.trustee_muxed_id
            , hist_ops.trustor
            , hist_ops.trustor_muxed
            , hist_ops.trustor_muxed_id
            , hist_ops.trustline_account_id
            , hist_ops.trustline_asset
            , hist_ops.value
            , hist_ops.clear_flags
            , hist_ops.clear_flags_s
            , hist_ops.destination_min
            , hist_ops.bump_to
            , hist_ops.sponsor
            , hist_ops.sponsored_id
            , hist_ops.begin_sponsor
            , hist_ops.begin_sponsor_muxed
            , hist_ops.begin_sponsor_muxed_id
            , hist_ops.authorize_to_maintain_liabilities
            , hist_ops.clawback_enabled
            , hist_ops.liquidity_pool_id
            , hist_ops.reserve_a_asset_type
            , hist_ops.reserve_a_asset_code
            , hist_ops.reserve_a_asset_issuer
            , hist_ops.reserve_a_max_amount
            , hist_ops.reserve_a_deposit_amount
            , hist_ops.reserve_b_asset_type
            , hist_ops.reserve_b_asset_code
            , hist_ops.reserve_b_asset_issuer
            , hist_ops.reserve_b_max_amount
            , hist_ops.reserve_b_deposit_amount
            , hist_ops.min_price
            , hist_ops.min_price_r
            , hist_ops.max_price
            , hist_ops.max_price_r
            , hist_ops.shares_received
            , hist_ops.reserve_a_min_amount
            , hist_ops.reserve_b_min_amount
            , hist_ops.shares
            , hist_ops.reserve_a_withdraw_amount
            , hist_ops.reserve_b_withdraw_amount
            , hist_ops.asset_balance_changes
            , hist_ops.parameters
            , hist_ops.parameters_decoded
            , hist_ops.function
            , hist_ops.address
            , hist_ops.soroban_operation_type
            , hist_ops.extend_to
            , hist_ops.contract_id
            , hist_ops.contract_code_hash
            , hist_ops.operation_result_code
            , hist_ops.operation_trace_code
            -- transaction fields
            , hist_trans.transaction_hash
            , hist_trans.ledger_sequence
            , hist_trans.txn_account
            , hist_trans.account_sequence
            , hist_trans.max_fee
            , hist_trans.txn_operation_count
            , hist_trans.txn_created_at
            , hist_trans.memo_type
            , hist_trans.memo
            , hist_trans.time_bounds
            , hist_trans.successful
            , hist_trans.fee_charged
            , hist_trans.fee_account
            , hist_trans.new_max_fee
            , hist_trans.account_muxed
            , hist_trans.fee_account_muxed
            --new protocol 19 fields for transaction preconditions
            , hist_trans.ledger_bounds
            , hist_trans.min_account_sequence
            , hist_trans.min_account_sequence_age
            , hist_trans.min_account_sequence_ledger_gap
            , hist_trans.extra_signers
            , hist_trans.resource_fee
            , hist_trans.soroban_resources_instructions
            , hist_trans.soroban_resources_read_bytes
            , hist_trans.soroban_resources_write_bytes
            , hist_trans.transaction_result_code
            , hist_trans.inclusion_fee_bid
            , hist_trans.inclusion_fee_charged
            , hist_trans.resource_fee_refund
            -- ledger fields
            , hist_ledg.ledger_hash
            , hist_ledg.previous_ledger_hash
            , hist_ledg.transaction_count
            , hist_ledg.ledger_operation_count
            , hist_ledg.closed_at
            , hist_ledg.ledger_id
            , hist_ledg.total_coins
            , hist_ledg.fee_pool
            , hist_ledg.base_fee
            , hist_ledg.base_reserve
            , hist_ledg.max_tx_set_size
            , hist_ledg.protocol_version
            , hist_ledg.successful_transaction_count
            , hist_ledg.failed_transaction_count
            -- json blob for operation details
            , hist_ops.details_json
            -- general fields
            , hist_ops.batch_id
            , hist_ops.batch_run_date
            -- missing ledger header fields
            , hist_ledg.soroban_fee_write_1kb
            , hist_ledg.node_id
            , hist_ledg.signature
            , hist_ledg.total_byte_size_of_bucket_list
            -- missing fee fields
            , hist_trans.non_refundable_resource_fee_charged
            , hist_trans.refundable_resource_fee_charged
            , hist_trans.rent_fee_charged
            , hist_trans.tx_signers
            , hist_trans.refundable_fee
        from history_operations as hist_ops
        join history_transactions as hist_trans
            on hist_ops.transaction_id = hist_trans.transaction_id
        join history_ledgers as hist_ledg
            on hist_trans.ledger_sequence = hist_ledg.sequence
    )

select
    *
    , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
from enriched_operations
