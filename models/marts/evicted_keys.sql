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
            , 'yes' as is_evicted
        from {{ ref('stg_history_ledgers') }} as shl
        cross join unnest(shl.evicted_ledger_keys_hash) as kh
        {% if is_incremental() %}
      where true
        and date(closed_at) >= date('{{ dbt_airflow_macros.ts(timezone=none) }}')

    {% endif %}
    )

    , restored as (
        select
            ledger_key_hash
            , closed_at
            , ledger_sequence
            , 'no' as is_evicted
        from {{ ref('stg_restored_key') }}
        {% if is_incremental() %}
      where true
        and date(closed_at) >= date('{{ dbt_airflow_macros.ts(timezone=none) }}')
    {% endif %}
    )

select * from evicted
union all
select * from restored
