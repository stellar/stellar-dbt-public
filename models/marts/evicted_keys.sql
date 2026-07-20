{% set meta_config = {
    "datadiff": {
        "unique_key": ["ledger_key_hash", "closed_at"],
        "exclude_columns": [],
        "min_match_percent": 98,
        "filters": {"column": "closed_at"},
    },
    "materialized": "table",
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
    )

    , restored as (
        select
            ledger_key_hash
            , closed_at
            , ledger_sequence
            , false as is_evicted
        from {{ ref('stg_restored_key') }}
    )

select * from evicted
union all
select * from restored
