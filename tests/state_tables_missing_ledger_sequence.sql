-- Strictly use enabled condition to restrict singular tests from running in dbt build tasks.
-- https://github.com/stellar/stellar-dbt-public/pull/95
{{ config(
    severity="error"
    , tags=["validate_state_tables"]
    , enabled=var("is_singular_airflow_task") == "true"
    )
}}

-- State tables export every 10 minutes (≈120 ledgers per snapshot at 5s
-- close time). Within the batch window, distinct ledger_sequence values
-- in each state table should be roughly 120 apart. A gap > 240 ledgers
-- indicates a missed export batch.

{% set state_tables = [
    'stg_accounts',
    'stg_account_signers',
    'stg_trust_lines',
    'stg_offers',
    'stg_liquidity_pools',
    'stg_claimable_balances',
    'stg_contract_data',
    'stg_contract_code',
    'stg_config_settings',
    'stg_ttl',
    'stg_restored_key',
] %}

with all_gaps as (
    {% for tbl in state_tables %}
    select
        '{{ tbl }}' as table_name
        , ledger_sequence
        , next_sequence
        , next_sequence - ledger_sequence as gap
    from (
        select
            ledger_sequence
            , lead(ledger_sequence) over (order by ledger_sequence) as next_sequence
        from (
            select distinct ledger_sequence
            from {{ ref(tbl) }}
            where closed_at >= timestamp(date('{{ var("batch_start_date") }}'))
                and closed_at < timestamp(date_add(date('{{ var("batch_end_date") }}'), interval 1 day))
        )
    )
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
)

select *
from all_gaps
where gap > 240
