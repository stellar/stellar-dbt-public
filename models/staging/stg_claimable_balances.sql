with raw_table as (
    select *
    {% if target.name == 'prod' %}
    from {{ source('crypto_stellar_internal_2', 'claimable_balances') }}
    {% else %}
    from {{ source('dbt_sample', 'sample_claimable_balances') }}
    {% endif %}
)

, claimable_balance as (
    select
        balance_id
        , claimants
        , asset_type
        , asset_code
        , asset_issuer
        , asset_amount
        , sponsor
        , flags
        , last_modified_ledger
        , last_entry_changed
        , deleted
        , batch_id
        , batch_run_date
        , batch_insert_ts
    from raw_table
)

select *
from claimable_balance
