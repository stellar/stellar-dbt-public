{% set meta_config = {
    "materialized": "incremental",
    "incremental_strategy": "merge",
    "unique_key": ["ledger_key_hash", "closed_at"],
    "tags": ["evicted_keys"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

with
    evicted as (
        select
            kh as ledger_key_hash
            , shl.closed_at
            , shl.sequence as ledger_sequence
            , true as is_evicted
        from {{ ref('stg_history_ledgers') }} as shl
        cross join unnest(shl.evicted_ledger_keys_hash) as kh
        where
            true
            -- Need to add/subtract one day to the window boundaries
            -- because this model runs at 30 min increments.
            -- Without the additional date buffering the following would occur
            -- * batch_start_date == '2025-01-01 01:00:00' --> '2025-01-01'
            -- * batch_end_date == '2025-01-01 01:30:00' --> '2025-01-01'
            -- * '2025-01-01 <= closed_at < '2025-01-01' would never have any data to processes
            and closed_at < timestamp(date_add(date('{{ var("batch_end_date") }}'), interval 1 day))
        {% if is_incremental() %}
            -- The extra day date_sub is useful in the case the first scheduled run for a day is skipped
            -- because the DAG is configured with catchup=false
            and closed_at >= timestamp(date_sub(date('{{ var("batch_start_date") }}'), interval 1 day))
    {% endif %}
    )

    , restored as (
        select
            ledger_key_hash
            , closed_at
            , ledger_sequence
            , false as is_evicted
        from {{ ref('stg_restored_key') }}
        where
            true
            and closed_at < timestamp(date_add(date('{{ var("batch_end_date") }}'), interval 1 day))
        {% if is_incremental() %}
            and closed_at >= timestamp(date_sub(date('{{ var("batch_start_date") }}'), interval 1 day))
    {% endif %}
    )

select * from evicted
union all
select * from restored
