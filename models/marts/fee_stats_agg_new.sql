{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["day_agg"],
    "tags": ["fee_stats"],
    "partition_by": {
        "field": "day_agg"
        , "data_type": "date"
        , "granularity": "month"
    }
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

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
            , coalesce(coalesce(resource_fee, 0) > 0, false) as is_soroban
        from {{ ref('stg_history_transactions') }}
        where
            batch_run_date < datetime(date('{{ var("batch_end_date") }}'))
        {% if is_incremental() %}
                and batch_run_date >= datetime(date('{{ var("batch_start_date") }}'))
            {% endif %}
    )

    -- GENERAL AGGREGATES (all txns → day grain)
    , general_agg as (
        select
            day_agg
            , sum(fee_charged) as total_fee_charged
            , avg(fee_charged) as avg_fee_charged
            , max(fee_charged) as max_fee_charged
            , count(*) as txn_count
            -- , sum(txn_operation_count) as total_txn_operation_count -- lets move this to soroban and classic specifc
            , min(ledger_sequence) as min_ledger_sequence
            , max(ledger_sequence) as max_ledger_sequence
        from base_txns
        group by day_agg
    )

    -- CLASSIC AGGREGATES (txns → day grain)
    -- For classic txns, fee_charged IS the inclusion fee (no resource_fee).
    -- Derived inclusion fee per op: fee_charged / effective_txn_operation_count
    , classic_agg as (
        select
            day_agg
            -- txn counts
            , count(*) as classic_txn_count
            -- fee_charged (= inclusion fee for classic)
            , sum(fee_charged) as classic_sum_fee_charged
            , avg(fee_charged) as classic_avg_fee_charged
            , max(fee_charged) as classic_max_fee_charged
            -- max_fee (what submitters were willing to pay)
            , sum(coalesce(new_max_fee, max_fee)) as classic_sum_max_fee
            , avg(coalesce(new_max_fee, max_fee)) as classic_avg_max_fee
            , max(coalesce(new_max_fee, max_fee)) as classic_max_max_fee
            -- derived inclusion fee per op
            , max(fee_charged / effective_txn_operation_count) as classic_max_inclusion_fee_per_op
            , avg(fee_charged / effective_txn_operation_count) as classic_avg_inclusion_fee_per_op
            , min(fee_charged / effective_txn_operation_count) as classic_min_inclusion_fee_per_op
            -- surge stats (ledger-level via count distinct)
            , count(distinct ledger_sequence) as classic_total_ledgers
            , count(
                distinct
                case
                    when fee_charged > effective_txn_operation_count * 100
                        then ledger_sequence
                end
            ) as classic_surge_ledger_count
            , countif(
                fee_charged > effective_txn_operation_count * 100
            ) as classic_total_surge_txn_count
            , sum(
                case
                    when fee_charged > effective_txn_operation_count * 100
                        then txn_operation_count
                end
            ) as classic_total_surge_operation_count
            , safe_divide(
                100.0 * count(
                    distinct
                    case
                        when fee_charged > effective_txn_operation_count * 100
                            then ledger_sequence
                    end
                )
                , count(distinct ledger_sequence)
            ) as classic_pct_ledgers_in_surge
        from base_txns
        where not is_soroban
        group by day_agg
    )

    -- SOROBAN AGGREGATES (txns → day grain)
    -- For soroban txns: fee_charged = resource_fee + inclusion_fee_charged
    , soroban_agg as (
        select
            day_agg
            -- txn counts
            , count(*) as soroban_txn_count

            -- fee_charged (total = resource_fee + inclusion_fee_charged)
            , sum(fee_charged) as soroban_sum_fee_charged
            , avg(fee_charged) as soroban_avg_fee_charged
            , max(fee_charged) as soroban_max_fee_charged

            -- inclusion fee
            , sum(inclusion_fee_charged) as soroban_sum_inclusion_fee_charged
            , avg(inclusion_fee_charged) as soroban_avg_inclusion_fee_charged
            , max(inclusion_fee_charged) as soroban_max_inclusion_fee_charged
            , sum(inclusion_fee_bid) as soroban_sum_inclusion_fee_bid
            , avg(inclusion_fee_bid) as soroban_avg_inclusion_fee_bid
            , max(inclusion_fee_bid) as soroban_max_inclusion_fee_bid
            -- derived inclusion fee per op
            , max(inclusion_fee_charged / effective_txn_operation_count) as soroban_max_inclusion_fee_per_op
            , avg(inclusion_fee_charged / effective_txn_operation_count) as soroban_avg_inclusion_fee_per_op
            , min(inclusion_fee_charged / effective_txn_operation_count) as soroban_min_inclusion_fee_per_op

            -- resource fee (total)
            , sum(resource_fee) as soroban_sum_resource_fee
            , avg(resource_fee) as soroban_avg_resource_fee
            , max(resource_fee) as soroban_max_resource_fee

            -- resource fee: non-refundable
            , sum(non_refundable_resource_fee_charged) as soroban_sum_non_refundable_resource_fee_charged
            , avg(non_refundable_resource_fee_charged) as soroban_avg_non_refundable_resource_fee_charged
            , max(non_refundable_resource_fee_charged) as soroban_max_non_refundable_resource_fee_charged

            -- resource fee: refundable
            , sum(refundable_resource_fee_charged) as soroban_sum_refundable_resource_fee_charged
            , avg(refundable_resource_fee_charged) as soroban_avg_refundable_resource_fee_charged
            , max(refundable_resource_fee_charged) as soroban_max_refundable_resource_fee_charged
            , sum(resource_fee_refund) as soroban_sum_resource_fee_refund
            , avg(resource_fee_refund) as soroban_avg_resource_fee_refund
            , max(resource_fee_refund) as soroban_max_resource_fee_refund
            , sum(rent_fee_charged) as soroban_sum_rent_fee_charged
            , avg(rent_fee_charged) as soroban_avg_rent_fee_charged
            , max(rent_fee_charged) as soroban_max_rent_fee_charged

            -- surge stats (ledger-level via count distinct)
            , count(distinct ledger_sequence) as soroban_total_ledgers
            , count(
                distinct
                case
                    when inclusion_fee_charged > effective_txn_operation_count * 100
                        then ledger_sequence
                end
            ) as soroban_surge_ledger_count
            , countif(
                inclusion_fee_charged > effective_txn_operation_count * 100
            ) as soroban_total_surge_txn_count
            , sum(
                case
                    when inclusion_fee_charged > effective_txn_operation_count * 100
                        then txn_operation_count
                end
            ) as soroban_total_surge_operation_count
            , safe_divide(
                100.0 * count(
                    distinct
                    case
                        when inclusion_fee_charged > effective_txn_operation_count * 100
                            then ledger_sequence
                    end
                )
                , count(distinct ledger_sequence)
            ) as soroban_pct_ledgers_in_surge
        from base_txns
        where is_soroban
        group by day_agg
    )

    -- TODO: implement soroban_fees_by_op_type --- do we need this?
    -- , soroban_op_type_agg as ()

    , final as (
        select
            general_agg.day_agg

            -- General
            , general_agg.total_fee_charged
            , general_agg.avg_fee_charged
            , general_agg.max_fee_charged
            , general_agg.txn_count
            , general_agg.total_txn_operation_count
            , general_agg.min_ledger_sequence
            , general_agg.max_ledger_sequence

            -- Classic: fee aggregates
            , classic_agg.classic_txn_count
            , classic_agg.classic_sum_fee_charged
            , classic_agg.classic_avg_fee_charged
            , classic_agg.classic_max_fee_charged
            , classic_agg.classic_sum_max_fee
            , classic_agg.classic_avg_max_fee
            , classic_agg.classic_max_max_fee
            , classic_agg.classic_max_inclusion_fee_per_op
            , classic_agg.classic_avg_inclusion_fee_per_op
            , classic_agg.classic_min_inclusion_fee_per_op

            -- Classic: surge
            , classic_agg.classic_total_ledgers
            , classic_agg.classic_surge_ledger_count
            , classic_agg.classic_total_surge_txn_count
            , classic_agg.classic_total_surge_operation_count
            , classic_agg.classic_pct_ledgers_in_surge

            -- Soroban: fee_charged (total)
            , soroban_agg.soroban_txn_count
            , soroban_agg.soroban_sum_fee_charged
            , soroban_agg.soroban_avg_fee_charged
            , soroban_agg.soroban_max_fee_charged

            -- Soroban: inclusion fee
            , soroban_agg.soroban_sum_inclusion_fee_charged
            , soroban_agg.soroban_avg_inclusion_fee_charged
            , soroban_agg.soroban_max_inclusion_fee_charged
            , soroban_agg.soroban_sum_inclusion_fee_bid
            , soroban_agg.soroban_avg_inclusion_fee_bid
            , soroban_agg.soroban_max_inclusion_fee_bid
            , soroban_agg.soroban_max_inclusion_fee_per_op
            , soroban_agg.soroban_avg_inclusion_fee_per_op
            , soroban_agg.soroban_min_inclusion_fee_per_op

            -- Soroban: resource fee (total)
            , soroban_agg.soroban_sum_resource_fee
            , soroban_agg.soroban_avg_resource_fee
            , soroban_agg.soroban_max_resource_fee

            -- Soroban: resource fee components
            , soroban_agg.soroban_sum_non_refundable_resource_fee_charged
            , soroban_agg.soroban_avg_non_refundable_resource_fee_charged
            , soroban_agg.soroban_max_non_refundable_resource_fee_charged
            , soroban_agg.soroban_sum_refundable_resource_fee_charged
            , soroban_agg.soroban_avg_refundable_resource_fee_charged
            , soroban_agg.soroban_max_refundable_resource_fee_charged
            , soroban_agg.soroban_sum_resource_fee_refund
            , soroban_agg.soroban_avg_resource_fee_refund
            , soroban_agg.soroban_max_resource_fee_refund
            , soroban_agg.soroban_sum_rent_fee_charged
            , soroban_agg.soroban_avg_rent_fee_charged
            , soroban_agg.soroban_max_rent_fee_charged

            -- Soroban: surge
            , soroban_agg.soroban_total_ledgers
            , soroban_agg.soroban_surge_ledger_count
            , soroban_agg.soroban_total_surge_txn_count
            , soroban_agg.soroban_total_surge_operation_count
            , soroban_agg.soroban_pct_ledgers_in_surge

            -- Calculated
            , general_agg.total_fee_charged / 10000000.0 as total_fee_charged_xlm

            -- Metadata
            , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts

        from general_agg
        left join classic_agg
            on general_agg.day_agg = classic_agg.day_agg
        left join soroban_agg
            on general_agg.day_agg = soroban_agg.day_agg
    )

select *
from final
