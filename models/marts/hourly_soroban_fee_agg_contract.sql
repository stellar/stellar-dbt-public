{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["hour_agg", "contract_id"],
    "tags": ["fee_stats"],
    "cluster_by": ["hour_agg", "contract_id"],
    "partition_by": {
        "field": "hour_agg",
        "data_type": "timestamp",
        "granularity": "day"
    },
    "incremental_predicates": [
        "DBT_INTERNAL_DEST.hour_agg >= timestamp(date_sub(date('" ~ var("batch_start_date") ~ "'), interval 1 day))"
    ]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
) }}

with
    contract_txns as (
        select
            timestamp_trunc(closed_at, hour) as hour_agg
            , contract_id
            , transaction_id
            -- fee_account is only populated on fee bump transactions.
            -- Coalesce with txn_account to capture the actual caller for
            -- regular Soroban transactions (the vast majority of calls).
            , coalesce(fee_account, txn_account) as fee_source_account
            , successful
            , fee_charged
            , max_fee
            , new_max_fee
            , txn_operation_count
            , case
                when new_max_fee is null then txn_operation_count
                else (txn_operation_count + 1)
            end as effective_operation_count
            , resource_fee
            , inclusion_fee_bid
            , inclusion_fee_charged
            , resource_fee_refund
            , non_refundable_resource_fee_charged
            , refundable_resource_fee_charged
            , rent_fee_charged
        from {{ ref('enriched_history_operations_soroban') }}
        where
            -- Exclude Soroban operations not tied to a specific contract
            -- (e.g. WASM uploads via invoke_host_function have no contract_id)
            contract_id is not null
            and closed_at < timestamp(date('{{ var("batch_end_date") }}'))
            {% if is_incremental() %}
                and closed_at >= timestamp(date_sub(date('{{ var("batch_start_date") }}'), interval 1 day))
            {% endif %}
        -- Deduplicate to transaction grain. Soroban txns currently have
        -- 1 operation, but this handles (potential) future multi-op Soroban transactions
        -- so fees are not double-counted.
        qualify row_number() over (partition by transaction_id order by op_id) = 1
    )

    , final as (
        select
            hour_agg
            , contract_id

            -- Volume
            , count(*) as txn_count
            , countif(not successful) as failed_txn_count
            , count(distinct fee_source_account) as unique_fee_source_accounts

            -- Fees (total)
            , sum(fee_charged) as total_fee_charged
            , avg(fee_charged) as avg_fee_charged
            , max(fee_charged) as max_fee_charged
            -- Use coalesce(new_max_fee, max_fee) to get the effective fee ceiling.
            -- For fee bump txns, new_max_fee is the actual ceiling (fee_charged never
            -- exceeds it); max_fee is just the inner txn's original max and is misleading.
            , sum(coalesce(new_max_fee, max_fee)) as total_max_fee
            , safe_divide(sum(fee_charged), sum(coalesce(new_max_fee, max_fee))) as fee_efficiency

            -- Inclusion fee
            , sum(inclusion_fee_charged) as total_inclusion_fee_charged
            , avg(inclusion_fee_charged) as avg_inclusion_fee_charged
            , sum(inclusion_fee_bid) as total_inclusion_fee_bid

            -- Resource fee
            , sum(resource_fee) as total_resource_fee
            , avg(resource_fee) as avg_resource_fee
            , sum(non_refundable_resource_fee_charged) as total_non_refundable_resource_fee
            , sum(refundable_resource_fee_charged) as total_refundable_resource_fee
            , sum(rent_fee_charged) as total_rent_fee
            , sum(resource_fee_refund) as total_resource_fee_refund
            , countif(
                inclusion_fee_charged > effective_operation_count * 100
            ) as surge_txn_count

            -- Metadata
            , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts

        from contract_txns
        group by hour_agg, contract_id
    )

select *
from final
