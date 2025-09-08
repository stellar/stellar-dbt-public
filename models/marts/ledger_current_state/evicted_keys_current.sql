{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["ledger_key_hash", "closed_at"],
    "incremental_strategy": "merge",
    "tags": ["current_state"]
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
            , 'yes' as is_evicted
        from {{ ref('stg_history_ledgers') }} as shl
        cross join unnest(shl.evicted_ledger_keys_hash) as kh
        {% if is_incremental() %}
      where true
        and TIMESTAMP(closed_at) >= TIMESTAMP_SUB('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL 2 day )

    {% endif %}
    )

    , restored as (
        select
            ledger_key_hash as key_hash
            , closed_at
            , 'no' as is_evicted
        from {{ ref('stg_restored_key') }}
        {% if is_incremental() %}
      where true
        and TIMESTAMP(closed_at) >= TIMESTAMP_SUB('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL 2 day )
    {% endif %}
    )

select * from evicted
union all
select * from restored
