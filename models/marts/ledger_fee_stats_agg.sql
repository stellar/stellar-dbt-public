{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["ledger_sequence"],
    "tags": ["hourly_fee_stats"],
    "cluster_by": ["day_agg", "ledger_sequence"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
) }}

with
    -- BASE: source read + classification + effective_txn_operation_count
    base_txns as (
        select
            cast(batch_run_date as date) as day_agg
            , ledger_sequence
            , transaction_id
            , fee_charged
            , max_fee
            , new_max_fee
            , txn_operation_count
            , case
                -- handling for fee bump transactions:
                -- If new_max_fee is not null, it's a fee bump txn, add 1 to the op count.
                -- Will be reflected later when calculating base inclusion fee.
                when new_max_fee is null then txn_operation_count
                else (txn_operation_count + 1)
            end as effective_txn_operation_count
            , fee_account
            , resource_fee
            , inclusion_fee_charged
            , inclusion_fee_bid
            , resource_fee_refund
            , non_refundable_resource_fee_charged
            , refundable_resource_fee_charged
            , rent_fee_charged
            , successful
            , coalesce(resource_fee, 0) > 0 as is_soroban
        from {{ ref('stg_history_transactions') }}
        where
            batch_run_date < datetime('{{ var("batch_end_date") }}') + interval 1 day
            {% if is_incremental() %}
                and batch_run_date >= datetime('{{ var("batch_start_date") }}') - interval 1 day
            {% endif %}
    )

    -- GENERAL AGGREGATES (all txns → ledger grain)
    , general_agg as (
        select
            day_agg
            , ledger_sequence
            , sum(fee_charged) as total_fee_charged
            , max(fee_charged) as max_fee_charged
            , count(*) as txn_count
            , countif(not successful) as failed_txn_count
            , sum(effective_txn_operation_count) as total_effective_txn_operation_count
            , sum(txn_operation_count) as total_raw_txn_operation_count
        from base_txns
        group by day_agg, ledger_sequence
    )

    -- CLASSIC AGGREGATES (classic txns → ledger grain)
    -- For classic txns, fee_charged IS the inclusion fee (no resource_fee).
    -- Derived inclusion fee per op: fee_charged / effective_txn_operation_count
    , classic_agg as (
        select
            day_agg
            , ledger_sequence
            -- txn counts
            , count(*) as classic_txn_count
            , countif(not successful) as classic_failed_txn_count
            , sum(effective_txn_operation_count) as classic_total_effective_operation_count
            , sum(txn_operation_count) as classic_total_raw_operation_count
            -- fee_charged (= inclusion fee for classic)
            , sum(fee_charged) as classic_sum_fee_charged
            , max(fee_charged) as classic_max_fee_charged
            -- max_fee (what submitters were willing to pay)
            , sum(coalesce(new_max_fee, max_fee)) as classic_sum_max_fee
            , max(coalesce(new_max_fee, max_fee)) as classic_max_max_fee
            -- derived inclusion fee per op
            , max(fee_charged / effective_txn_operation_count) as classic_max_inclusion_fee_per_op
            , min(fee_charged / effective_txn_operation_count) as classic_min_inclusion_fee_per_op
            -- surge stats (at ledger grain, simplifies to txn-level counts + a flag)
            , countif(
                fee_charged > effective_txn_operation_count * 100
            ) as classic_surge_txn_count
            , sum(
                case
                    when fee_charged > effective_txn_operation_count * 100
                        then effective_txn_operation_count
                end
            ) as classic_surge_operation_count
        from base_txns
        where not is_soroban
        group by day_agg, ledger_sequence
    )

    -- SOROBAN AGGREGATES (soroban txns → ledger grain)
    -- For soroban txns: fee_charged = resource_fee + inclusion_fee_charged
    , soroban_agg as (
        select
            day_agg
            , ledger_sequence
            -- txn counts
            , count(*) as soroban_txn_count
            , countif(not successful) as soroban_failed_txn_count
            , sum(effective_txn_operation_count) as soroban_total_effective_operation_count
            , sum(txn_operation_count) as soroban_total_raw_operation_count

            -- fee_charged (total = resource_fee + inclusion_fee_charged)
            , sum(fee_charged) as soroban_sum_fee_charged
            , max(fee_charged) as soroban_max_fee_charged

            -- inclusion fee
            , sum(inclusion_fee_charged) as soroban_sum_inclusion_fee_charged
            , max(inclusion_fee_charged) as soroban_max_inclusion_fee_charged
            , sum(inclusion_fee_bid) as soroban_sum_inclusion_fee_bid
            , max(inclusion_fee_bid) as soroban_max_inclusion_fee_bid
            -- derived inclusion fee per op
            , max(inclusion_fee_charged / effective_txn_operation_count) as soroban_max_inclusion_fee_per_op
            , min(inclusion_fee_charged / effective_txn_operation_count) as soroban_min_inclusion_fee_per_op

            -- resource fee (total)
            , sum(resource_fee) as soroban_sum_resource_fee
            , max(resource_fee) as soroban_max_resource_fee
            , min(resource_fee) as soroban_min_resource_fee

            -- resource fee: non-refundable
            , sum(non_refundable_resource_fee_charged) as soroban_sum_non_refundable_resource_fee_charged
            , max(non_refundable_resource_fee_charged) as soroban_max_non_refundable_resource_fee_charged
            , min(non_refundable_resource_fee_charged) as soroban_min_non_refundable_resource_fee_charged

            -- resource fee: refundable
            , sum(refundable_resource_fee_charged) as soroban_sum_refundable_resource_fee_charged
            , max(refundable_resource_fee_charged) as soroban_max_refundable_resource_fee_charged
            , min(refundable_resource_fee_charged) as soroban_min_refundable_resource_fee_charged
            , sum(resource_fee_refund) as soroban_sum_resource_fee_refund
            , max(resource_fee_refund) as soroban_max_resource_fee_refund
            , min(resource_fee_refund) as soroban_min_resource_fee_refund
            , sum(rent_fee_charged) as soroban_sum_rent_fee_charged
            , max(rent_fee_charged) as soroban_max_rent_fee_charged
            , min(rent_fee_charged) as soroban_min_rent_fee_charged

            -- surge stats (at ledger grain, simplifies to txn-level counts + a flag)
            , countif(
                inclusion_fee_charged > effective_txn_operation_count * 100
            ) as soroban_surge_txn_count
            , sum(
                case
                    when inclusion_fee_charged > effective_txn_operation_count * 100
                        then effective_txn_operation_count
                end
            ) as soroban_surge_operation_count
        from base_txns
        where is_soroban
        group by day_agg, ledger_sequence
    )

    -- LEDGER INFO: fee_pool from history_ledgers (already at ledger grain)
    , ledger_info as (
        select
            sequence as ledger_sequence
            , closed_at
            , fee_pool
        from {{ ref('stg_history_ledgers') }}
        where
            batch_run_date < datetime('{{ var("batch_end_date") }}') + interval 1 day
            {% if is_incremental() %}
                and batch_run_date >= datetime('{{ var("batch_start_date") }}') - interval 1 day
            {% endif %}
    )

    , final as (
        select
            general_agg.day_agg
            , general_agg.ledger_sequence

            -- General
            , general_agg.total_fee_charged
            , general_agg.max_fee_charged
            , general_agg.txn_count
            , general_agg.failed_txn_count
            , general_agg.total_effective_txn_operation_count
            , general_agg.total_raw_txn_operation_count

            -- Classic: fee aggregates
            , coalesce(classic_agg.classic_txn_count, 0) as classic_txn_count
            , coalesce(classic_agg.classic_failed_txn_count, 0) as classic_failed_txn_count
            , coalesce(classic_agg.classic_total_effective_operation_count, 0) as classic_total_effective_operation_count
            , coalesce(classic_agg.classic_total_raw_operation_count, 0) as classic_total_raw_operation_count
            , coalesce(classic_agg.classic_sum_fee_charged, 0) as classic_sum_fee_charged
            , classic_agg.classic_max_fee_charged
            , coalesce(classic_agg.classic_sum_max_fee, 0) as classic_sum_max_fee
            , classic_agg.classic_max_max_fee
            , classic_agg.classic_max_inclusion_fee_per_op
            , classic_agg.classic_min_inclusion_fee_per_op

            -- Classic: surge
            , coalesce(classic_agg.classic_surge_txn_count, 0) as classic_surge_txn_count
            , coalesce(classic_agg.classic_surge_operation_count, 0) as classic_surge_operation_count
            , coalesce(classic_agg.classic_surge_txn_count, 0) > 0 as classic_is_surge_ledger

            -- Soroban: fee_charged (total)
            , coalesce(soroban_agg.soroban_txn_count, 0) as soroban_txn_count
            , coalesce(soroban_agg.soroban_failed_txn_count, 0) as soroban_failed_txn_count
            , coalesce(soroban_agg.soroban_total_effective_operation_count, 0) as soroban_total_effective_operation_count
            , coalesce(soroban_agg.soroban_total_raw_operation_count, 0) as soroban_total_raw_operation_count
            , coalesce(soroban_agg.soroban_sum_fee_charged, 0) as soroban_sum_fee_charged
            , soroban_agg.soroban_max_fee_charged

            -- Soroban: inclusion fee
            , coalesce(soroban_agg.soroban_sum_inclusion_fee_charged, 0) as soroban_sum_inclusion_fee_charged
            , soroban_agg.soroban_max_inclusion_fee_charged
            , coalesce(soroban_agg.soroban_sum_inclusion_fee_bid, 0) as soroban_sum_inclusion_fee_bid
            , soroban_agg.soroban_max_inclusion_fee_bid
            , soroban_agg.soroban_max_inclusion_fee_per_op
            , soroban_agg.soroban_min_inclusion_fee_per_op

            -- Soroban: resource fee (total)
            , coalesce(soroban_agg.soroban_sum_resource_fee, 0) as soroban_sum_resource_fee
            , soroban_agg.soroban_max_resource_fee
            , soroban_agg.soroban_min_resource_fee

            -- Soroban: resource fee components
            , coalesce(soroban_agg.soroban_sum_non_refundable_resource_fee_charged, 0) as soroban_sum_non_refundable_resource_fee_charged
            , soroban_agg.soroban_max_non_refundable_resource_fee_charged
            , soroban_agg.soroban_min_non_refundable_resource_fee_charged
            , coalesce(soroban_agg.soroban_sum_refundable_resource_fee_charged, 0) as soroban_sum_refundable_resource_fee_charged
            , soroban_agg.soroban_max_refundable_resource_fee_charged
            , soroban_agg.soroban_min_refundable_resource_fee_charged
            , coalesce(soroban_agg.soroban_sum_resource_fee_refund, 0) as soroban_sum_resource_fee_refund
            , soroban_agg.soroban_max_resource_fee_refund
            , soroban_agg.soroban_min_resource_fee_refund
            , coalesce(soroban_agg.soroban_sum_rent_fee_charged, 0) as soroban_sum_rent_fee_charged
            , soroban_agg.soroban_max_rent_fee_charged
            , soroban_agg.soroban_min_rent_fee_charged

            -- Soroban: surge
            , coalesce(soroban_agg.soroban_surge_txn_count, 0) as soroban_surge_txn_count
            , coalesce(soroban_agg.soroban_surge_operation_count, 0) as soroban_surge_operation_count
            , coalesce(soroban_agg.soroban_surge_txn_count, 0) > 0 as soroban_is_surge_ledger

            -- Ledger info
            , ledger_info.closed_at
            , ledger_info.fee_pool

            -- Metadata
            , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts

        from general_agg
        left join classic_agg
            on general_agg.day_agg = classic_agg.day_agg
            and general_agg.ledger_sequence = classic_agg.ledger_sequence
        left join soroban_agg
            on general_agg.day_agg = soroban_agg.day_agg
            and general_agg.ledger_sequence = soroban_agg.ledger_sequence
        left join ledger_info
            on general_agg.ledger_sequence = ledger_info.ledger_sequence
    )

select *
from final
