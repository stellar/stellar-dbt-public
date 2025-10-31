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
            and closed_at < timestamp(date('{{ var("batch_end_date") }}'))
        {% if is_incremental() %}
            and closed_at >= timestamp(date('{{ var("batch_start_date") }}'))
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
            and closed_at < timestamp(date('{{ var("batch_end_date") }}'))
        {% if is_incremental() %}
            and closed_at >= timestamp(date('{{ var("batch_start_date") }}'))
    {% endif %}
    )

select * from evicted
union all
select * from restored
