{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["hour_agg", "fee_source_account"],
    "tags": ["fee_stats"],
    "cluster_by": ["hour_agg", "fee_source_account"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
) }}

with
    base_txns as (
        select
            timestamp_trunc(closed_at, hour) as hour_agg
            , transaction_id
            -- fee_account is only populated on fee bump transactions (where a separate
            -- account sponsors the fees). For regular transactions, the originating
            -- account (txn_account) pays the fees. Coalesce to get the actual fee payer.
            -- TODO: Review whether we should preserve the raw fee_account column separately
            -- to distinguish fee bump sponsors from accounts paying their own fees.
            , coalesce(fee_account, txn_account) as fee_source_account
            , fee_charged
            , max_fee
            , new_max_fee
            , txn_operation_count
            , case
                when new_max_fee is null then txn_operation_count
                else (txn_operation_count + 1)
            end as effective_operation_count
            , successful
            , resource_fee
            , inclusion_fee_bid
            , inclusion_fee_charged
            , resource_fee_refund
            , non_refundable_resource_fee_charged
            , refundable_resource_fee_charged
            , rent_fee_charged
        from {{ ref('stg_history_transactions') }}
        where
            closed_at < timestamp(date('{{ var("batch_end_date") }}'))
            {% if is_incremental() %}
                and closed_at >= timestamp(date_sub(date('{{ var("batch_start_date") }}'), interval 1 day))
            {% endif %}
    )

    , classified as (
        select
            *
            , coalesce(resource_fee > 0, false) as is_soroban
        from base_txns
    )

    , final as (
        select
            hour_agg
            , fee_source_account

            -- General
            , count(*) as txn_count
            , countif(not successful) as failed_txn_count
            , sum(fee_charged) as total_fee_charged
            , sum(max_fee) as total_max_fee
            , safe_divide(sum(fee_charged), sum(max_fee)) as fee_efficiency
            , sum(effective_operation_count) as total_effective_operation_count
            , sum(txn_operation_count) as total_raw_operation_count

            -- Classic
            , countif(not is_soroban) as classic_txn_count
            , countif(not is_soroban and not successful) as classic_failed_txn_count
            , sum(case when not is_soroban then fee_charged end) as classic_total_fee_charged
            , sum(case when not is_soroban then max_fee end) as classic_total_max_fee
            , sum(case when not is_soroban then effective_operation_count end) as classic_total_effective_operation_count

            -- Soroban
            , countif(is_soroban) as soroban_txn_count
            , countif(is_soroban and not successful) as soroban_failed_txn_count
            , sum(case when is_soroban then fee_charged end) as soroban_total_fee_charged
            , sum(case when is_soroban then inclusion_fee_charged end) as soroban_total_inclusion_fee_charged
            , sum(case when is_soroban then inclusion_fee_bid end) as soroban_total_inclusion_fee_bid
            , sum(case when is_soroban then resource_fee end) as soroban_total_resource_fee
            , sum(case when is_soroban then non_refundable_resource_fee_charged end) as soroban_total_non_refundable_resource_fee
            , sum(case when is_soroban then refundable_resource_fee_charged end) as soroban_total_refundable_resource_fee
            , sum(case when is_soroban then rent_fee_charged end) as soroban_total_rent_fee
            , sum(case when is_soroban then resource_fee_refund end) as soroban_total_resource_fee_refund
            , sum(case when is_soroban then effective_operation_count end) as soroban_total_effective_operation_count

            -- Metadata
            , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts

        from classified
        group by hour_agg, fee_source_account
    )

-- NOTE: This model cannot directly link a fee_source_account to a specific contract_id.
-- To answer "which contracts is this account invoking?", join to stg_history_transactions
-- and enriched_history_operations_soroban on transaction_id for the relevant time window.
-- The hourly_soroban_fee_agg_contract model provides the contract-level view but does not
-- include fee_source_account attribution.
select *
from final
