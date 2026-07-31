{% set batch_size = microbatch_batch_size() %}
{% set begin = microbatch_begin('2015-09-30') %}

{% set meta_config = {
    "datadiff": {
        "unique_key": ["unique_key"],
        "exclude_columns": [],
        "min_match_percent": 98,
        "filters": {"column": "closed_at"},
    },
    "materialized": "incremental",
    "incremental_strategy": "microbatch",
    "event_time": "closed_at",
    "batch_size": batch_size,
    "concurrent_batches": true,
    "begin": begin,
    "tags": ["token_transfer"],
    "partition_by": {
        "field": "closed_at"
        , "data_type": "timestamp"
        , "granularity": "day"
        , "copy_partitions": true}
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

select *
from {{ ref('int_token_transfer_enrichment') }}
