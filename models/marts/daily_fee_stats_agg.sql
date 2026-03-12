{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["day_agg"],
    "tags": ["daily_fee_stats"],
    "cluster_by": ["day_agg"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

with
    ledger_stats as (
        select *
        from {{ ref('ledger_fee_stats_agg') }}
        where
            day_agg < date('{{ var("batch_end_date") }}')
            {% if is_incremental() %}
                and day_agg >= date('{{ var("batch_start_date") }}')
            {% endif %}
    )

    , final as (
        select
            day_agg

            -- General
            , sum(total_fee_charged) as total_fee_charged
            , max(max_fee_charged) as max_fee_charged
            , sum(txn_count) as txn_count
            , sum(failed_txn_count) as failed_txn_count
            , sum(total_effective_txn_operation_count) as total_effective_txn_operation_count
            , sum(total_raw_txn_operation_count) as total_raw_txn_operation_count
            , min(ledger_sequence) as min_ledger_sequence
            , max(ledger_sequence) as max_ledger_sequence
            , count(*) as total_ledgers

            -- Classic: fee aggregates
            , sum(classic_txn_count) as classic_txn_count
            , sum(classic_failed_txn_count) as classic_failed_txn_count
            , sum(classic_total_effective_operation_count) as classic_total_effective_operation_count
            , sum(classic_total_raw_operation_count) as classic_total_raw_operation_count
            , sum(classic_sum_fee_charged) as classic_sum_fee_charged
            , max(classic_max_fee_charged) as classic_max_fee_charged
            , sum(classic_sum_max_fee) as classic_sum_max_fee
            , max(classic_max_max_fee) as classic_max_max_fee
            -- derived inclusion fee per op
            , max(classic_max_inclusion_fee_per_op) as classic_max_inclusion_fee_per_op
            , min(classic_min_inclusion_fee_per_op) as classic_min_inclusion_fee_per_op

            -- Classic: surge
            , countif(classic_txn_count > 0) as classic_total_ledgers
            , countif(classic_is_surge_ledger) as classic_surge_ledger_count
            , sum(classic_surge_txn_count) as classic_total_surge_txn_count
            , sum(classic_surge_operation_count) as classic_total_surge_operation_count
            , safe_divide(
                100.0 * countif(classic_is_surge_ledger)
                , countif(classic_txn_count > 0)
            ) as classic_pct_ledgers_in_surge

            -- Soroban: fee_charged (total)
            , sum(soroban_txn_count) as soroban_txn_count
            , sum(soroban_failed_txn_count) as soroban_failed_txn_count
            , sum(soroban_total_effective_operation_count) as soroban_total_effective_operation_count
            , sum(soroban_total_raw_operation_count) as soroban_total_raw_operation_count
            , sum(soroban_sum_fee_charged) as soroban_sum_fee_charged
            , max(soroban_max_fee_charged) as soroban_max_fee_charged

            -- Soroban: inclusion fee
            , sum(soroban_sum_inclusion_fee_charged) as soroban_sum_inclusion_fee_charged
            , max(soroban_max_inclusion_fee_charged) as soroban_max_inclusion_fee_charged
            , sum(soroban_sum_inclusion_fee_bid) as soroban_sum_inclusion_fee_bid
            , max(soroban_max_inclusion_fee_bid) as soroban_max_inclusion_fee_bid
            -- derived inclusion fee per op
            , max(soroban_max_inclusion_fee_per_op) as soroban_max_inclusion_fee_per_op
            , min(soroban_min_inclusion_fee_per_op) as soroban_min_inclusion_fee_per_op

            -- Soroban: resource fee (total)
            , sum(soroban_sum_resource_fee) as soroban_sum_resource_fee
            , max(soroban_max_resource_fee) as soroban_max_resource_fee
            , min(soroban_min_resource_fee) as soroban_min_resource_fee

            -- Soroban: resource fee components
            , sum(soroban_sum_non_refundable_resource_fee_charged) as soroban_sum_non_refundable_resource_fee_charged
            , max(soroban_max_non_refundable_resource_fee_charged) as soroban_max_non_refundable_resource_fee_charged
            , min(soroban_min_non_refundable_resource_fee_charged) as soroban_min_non_refundable_resource_fee_charged

            , sum(soroban_sum_refundable_resource_fee_charged) as soroban_sum_refundable_resource_fee_charged
            , max(soroban_max_refundable_resource_fee_charged) as soroban_max_refundable_resource_fee_charged
            , min(soroban_min_refundable_resource_fee_charged) as soroban_min_refundable_resource_fee_charged

            , sum(soroban_sum_resource_fee_refund) as soroban_sum_resource_fee_refund
            , max(soroban_max_resource_fee_refund) as soroban_max_resource_fee_refund
            , min(soroban_min_resource_fee_refund) as soroban_min_resource_fee_refund

            , sum(soroban_sum_rent_fee_charged) as soroban_sum_rent_fee_charged
            , max(soroban_max_rent_fee_charged) as soroban_max_rent_fee_charged
            , min(soroban_min_rent_fee_charged) as soroban_min_rent_fee_charged

            -- Soroban: surge
            , countif(soroban_txn_count > 0) as soroban_total_ledgers
            , countif(soroban_is_surge_ledger) as soroban_surge_ledger_count
            , sum(soroban_surge_txn_count) as soroban_total_surge_txn_count
            , sum(soroban_surge_operation_count) as soroban_total_surge_operation_count
            , safe_divide(
                100.0 * countif(soroban_is_surge_ledger)
                , countif(soroban_txn_count > 0)
            ) as soroban_pct_ledgers_in_surge

            -- Total surge (classic or soroban)
            , safe_divide(
                100.0 * countif(classic_is_surge_ledger or soroban_is_surge_ledger)
                , count(*)
            ) as total_pct_ledgers_in_surge

            -- Ledger info
            , sum(fee_pool) as fee_pool

            -- Metadata
            , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts

        from ledger_stats
        group by day_agg
    )

select *
from final
