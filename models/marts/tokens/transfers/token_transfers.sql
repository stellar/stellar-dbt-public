{% set batch_size = 'year' if flags.FULL_REFRESH else 'day' %}

{% set meta_config = {
    "materialized": "incremental",
    "incremental_strategy": "microbatch",
    "event_time": "closed_at",
    "batch_size": batch_size,
    "concurrent_batches": flags.FULL_REFRESH,
    "begin": "2015-09-30",
    "tags": ["token_transfer"],
    "partition_by": {
        "field": "closed_at"
        , "data_type": "timestamp"
        , "granularity": "day"
        , "copy_partitions": flags.FULL_REFRESH}
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

select *
from {{ ref('int_token_transfer_enrichment') }}
