{% set meta_config = {
    "materialized": "incremental",
    "incremental_strategy": "merge",
    "unique_key": "unique_key",
    "tags": ["token_transfer"],
    "partition_by": {
        "field": "closed_at"
        , "data_type": "timestamp"
        , "granularity": "month"}
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

select *
from {{ ref('int_token_transfer_enrichment') }}
where
    closed_at < timestamp(date_add(date('{{ var("batch_end_date") }}'), interval 1 day))
    {% if is_incremental() %}
        and closed_at >= timestamp(date_sub(date('{{ var("batch_start_date") }}'), interval 1 day))
    {% endif %}
