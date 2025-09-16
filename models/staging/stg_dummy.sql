{% set meta_config = {
    "materialized": "table"
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

select
    'test' as test_case_description
    , 'G1' as account_id
    , 100 as balance
    , cast('2025-01-01' as timestamp) as closed_at
