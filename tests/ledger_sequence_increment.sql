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
    'stg_history_effects',
    'stg_history_contract_events',
    'stg_token_transfers_raw',
] %}

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

{% set snapshot_tables = [
    'accounts_snapshot',
    'contract_data_snapshot',
    'evicted_keys_snapshot',
    'liquidity_pools_snapshot',
    'reflector_prices_data_cex_snapshot',
    'reflector_prices_data_fex_snapshot',
    'reflector_prices_data_sdex_snapshot',
    'trustlines_snapshot',
    'asset_prices_coingecko_snapshot',
    'recognized_asset_prices_snapshot',
    'wisdom_tree_asset_prices_data',
] %}

{% set current_tables = [
    'accounts_current',
    'account_signers_current',
    'trust_lines_current',
    'offers_current',
    'liquidity_pools_current',
    'claimable_balances_current',
    'contract_data_current',
    'contract_code_current',
    'config_settings_current',
    'ttl_current',
] %}

{% set fee_stats_tables = [
    'ledger_fee_stats_agg',
] %}

{% set table_groups = {
    'history_tables': history_tables,
    'state_tables': state_tables,
    'snapshot_tables': snapshot_tables,
    'current_tables': current_tables,
    'fee_stats_tables': fee_stats_tables,
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
        or max_sequence != prev_sequence + 1
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
    {% endif %}
)

select *
from all_gaps
