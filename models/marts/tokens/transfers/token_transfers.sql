{# This table is partitioned by MONTH, so batches must never be finer than a month:
   BigQuery microbatch is a dynamic insert_overwrite that replaces every partition
   present in a batch's output, and a sub-month batch would overwrite a whole month
   partition with partial data. dbt aligns batch boundaries to the batch_size period
   (CLI --event-time windows are truncated/ceilinged), so month batches always cover
   full month partitions. MICROBATCH_SIZE=year is allowed for backfills — see
   macros/bq_validate_microbatch_config.sql #}
{% set requested_batch_size = var('microbatch_size', 'day') %}
{% set batch_size = 'month' if requested_batch_size == 'day' else requested_batch_size %}

{% set meta_config = {
    "materialized": "incremental",
    "incremental_strategy": "microbatch",
    "event_time": "closed_at",
    "batch_size": batch_size,
    "begin": "2015-09-30",
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
-- microbatch auto-filters this ref to the batch window via event_time
from {{ ref('int_token_transfer_enrichment') }}
