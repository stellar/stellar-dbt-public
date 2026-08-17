-- Strictly use enabled condition to restrict singular tests from running in dbt build tasks.
-- https://github.com/stellar/stellar-dbt-public/pull/95
{{ config(
    severity="error"
    , tags=["validate_token_transfer_tables"]
    , enabled=var("is_singular_airflow_task") == "true"
    )
}}

-- The circulating supply of a given token should be >= 0. Mirrors
-- no_negative_circulating_supply (which runs against the raw event
-- source) but evaluates the mart so any enrichment-introduced drift
-- between raw events and token_transfers is caught here.
with mints as (
    select
        contract_id
        , sum(cast(amount_raw as numeric)) as total
    from {{ ref('token_transfers') }}
    where true
        and event_topic = 'mint'
    group by 1
)

, burns as (
    select
        contract_id
        , sum(cast(amount_raw as numeric)) as total
    from {{ ref('token_transfers') }}
    where true
        and event_topic = 'burn'
    group by 1
)

select
    mints.contract_id
    , sum(mints.total - burns.total) as total
from mints
-- not all assets have burned
left join burns
    on mints.contract_id = burns.contract_id
where true
    -- the list of non-compliant custom token contracts that carry a negative
    -- balance now lives in seeds/public_test_exceptions.csv rather than inline here
    {{ exclude_test_exceptions(
        'token_transfers_no_negative_circulating_supply'
        , entity_columns={'contract_id': 'mints.contract_id'}
    ) }}
group by 1
having sum(mints.total - burns.total) < 0
