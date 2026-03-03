{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["transaction_hash", "contract_id", "metric_key"],
    "partition_by": {
        "field": "closed_at"
        , "data_type": "timestamp"
        , "granularity": "day"},
    "cluster_by": ["contract_id", "metric_key"],
    "incremental_predicates": ["DBT_INTERNAL_DEST.closed_at >= timestamp_sub(timestamp(date('" ~ var('batch_start_date') ~ "')), interval 1 day)"],
    "tags": ["soroban", "network_stats"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

select
    transaction_hash
    , ledger_sequence
    , closed_at
    , contract_id
    , safe_cast(json_value(topics_decoded[1], '$.symbol') as string) as metric_key
    , safe_cast(json_value(data_decoded, '$.u64') as int64) as metric_value
from {{ ref('stg_history_contract_events') }}
where
    json_value(topics_decoded[0], '$.symbol') = 'core_metrics'
    and type = 2
    and closed_at < timestamp(date('{{ var("batch_end_date") }}'))
{% if is_incremental() %}
    and closed_at >= timestamp(date('{{ var("batch_start_date") }}'))
{% endif %}
