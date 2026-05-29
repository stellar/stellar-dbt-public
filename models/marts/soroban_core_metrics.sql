{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["transaction_hash", "metric_key"],
    "tags": ["soroban_core_metrics"],
    "cluster_by": ["contract_id"],
    "partition_by": {
        "field": "closed_at",
        "data_type": "timestamp",
        "granularity": "day"
    },
    "incremental_predicates": [
        "DBT_INTERNAL_DEST.closed_at >= timestamp(date_sub(date('" ~ var("batch_start_date") ~ "'), interval 1 day))"
    ]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
) }}

with
    events as (
        select
            closed_at
            , ledger_sequence
            , transaction_hash
            , metric_key
            , metric_value
        from {{ ref('stg_soroban_core_metrics_events') }}
        where closed_at < timestamp(date_add(date('{{ var("batch_end_date") }}'), interval 1 day))
        {% if is_incremental() %}
            and closed_at >= timestamp(date_sub(date('{{ var("batch_start_date") }}'), interval 1 day))
        {% endif %}
    )

    , invocations as (
        select
            transaction_hash
            , contract_id
        from {{ ref('enriched_history_operations_soroban') }}
        where
            op_type = 24
            and contract_id is not null
            and contract_id != ''
            and closed_at < timestamp(date_add(date('{{ var("batch_end_date") }}'), interval 1 day))
            {% if is_incremental() %}
                and closed_at >= timestamp(date_sub(date('{{ var("batch_start_date") }}'), interval 1 day))
            {% endif %}
        -- Defensive dedup: Soroban txns currently have 1 operation, but this
        -- handles (potential) future multi-op Soroban transactions so contract_id
        -- doesn't fan out in the join.
        qualify row_number() over (partition by transaction_hash order by op_id) = 1
    )

    , final as (
        select
            events.closed_at
            , events.ledger_sequence
            , events.transaction_hash
            , invocations.contract_id
            , events.metric_key
            , events.metric_value
            , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
        from events
        left join invocations
            on events.transaction_hash = invocations.transaction_hash
    )
  
select *
from final
