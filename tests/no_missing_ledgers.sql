-- Strictly use enabled condition to restrict singular tests from running in dbt build tasks.
-- https://github.com/stellar/stellar-dbt-public/pull/95
{{ config(
    severity="error"
    , tags=["validate_no_missing_ledgers"]
    , enabled=var("is_singular_airflow_task") == "true"
    )
}}

{% set history_tables = [
    'stg_history_ledgers',
    'stg_history_transactions',
    'stg_history_operations',
    'stg_token_transfers_raw',
] %}

{% set state_tables = [
    'stg_accounts',
    'stg_account_signers',
    'stg_trust_lines',
    'stg_offers',
    'stg_liquidity_pools',
    'stg_contract_data',
    'stg_ttl',
] %}

{% set dbt_hourly_tables = [
    'token_transfers',
    'enriched_history_operations',
    'ledger_fee_stats_agg',
] %}

{% set table_groups = {
    'history_tables': history_tables,
    'state_tables': state_tables,
    'dbt_hourly': dbt_hourly_tables,
} %}

-- Tables whose sequence column is named `sequence` instead of `ledger_sequence`.
{% set sequence_column_override = [
    'stg_history_ledgers',
] %}

{% set table_group_name = var('table_group_name', none) %}
{% set table_name = var('table_name', none) %}

{% if table_group_name %}
    {% set tables_to_check = table_groups[table_group_name] %}
{% elif table_name %}
    {% set tables_to_check = [table_name] %}
{% else %}
    {% set tables_to_check = [] %}
    {% for group_tables in table_groups.values() %}
        {% do tables_to_check.extend(group_tables) %}
    {% endfor %}
{% endif %}

with all_gaps as (
    {% if tables_to_check | length == 0 %}
    select
        cast(null as string) as table_name
        , cast(null as timestamp) as closed_at
        , cast(null as int64) as max_sequence
        , cast(null as int64) as prev_sequence
    where false
    {% else %}
    {% for tbl in tables_to_check %}
    {% set sequence_col = 'sequence' if tbl in sequence_column_override else 'ledger_sequence' %}
    select
        '{{ tbl }}' as table_name
        , closed_at
        , max_sequence
        , prev_sequence
    from (
        select
            closed_at
            , max_sequence
            , lead(max_sequence) over (order by closed_at desc) as prev_sequence
        from (
            select
                closed_at
                , max({{ sequence_col }}) as max_sequence
            from {{ ref(tbl) }}
            where closed_at >= TIMESTAMP_SUB(TIMESTAMP('{{ var("batch_start_date") }}'), INTERVAL 7 DAY)
            group by closed_at
        )
    )
    where prev_sequence >= max_sequence
        or (
            (max_sequence != prev_sequence + 1)
            and ((max_sequence - prev_sequence) > 50)
        )
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
    {% endif %}
)

, stale_latest as (
    {% if tables_to_check | length == 0 %}
    select
        cast(null as string) as table_name
        , cast(null as timestamp) as latest_closed_at
    where false
    {% else %}
    {% for tbl in tables_to_check %}
    select
        '{{ tbl }}' as table_name
        , max(closed_at) as latest_closed_at
    from {{ ref(tbl) }}
    where closed_at >= TIMESTAMP_SUB(TIMESTAMP('{{ var("batch_start_date") }}'), INTERVAL 7 DAY)
    having max(closed_at) is null
        or max(closed_at) < TIMESTAMP_SUB(TIMESTAMP('{{ var("batch_end_date") }}'), INTERVAL 5 MINUTE)
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
    {% endif %}
)

, failures as (
    select
        table_name
        , closed_at
        , max_sequence
        , prev_sequence
        , 'gap' as failure_reason
    from all_gaps
    union all
    select
        table_name
        , latest_closed_at as closed_at
        , cast(null as int64) as max_sequence
        , cast(null as int64) as prev_sequence
        , 'stale_latest' as failure_reason
    from stale_latest
)

select *
from failures
