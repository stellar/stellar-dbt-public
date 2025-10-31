{% set meta_config = {
    "materialized": "incremental",
    "unique_key": "liquidity_pool_id",
    "cluster_by": ["asset_a_code", "asset_a_issuer", "asset_b_code", "asset_b_issuer"],
    "tags": ["current_state"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

/* Finds the latest state of each liquidity pool in the `liquidity_pools` table.
   Ranks each record (grain: one row per pool) using
   last modified ledger sequence number. View includes all pools.
   (Deleted and Existing). View matches the Horizon snapshotted state tables. */

with
    current_lps as (
        select
            lp.liquidity_pool_id
            , lp.fee
            , lp.trustline_count
            , lp.pool_share_count
            , case
                when lp.asset_a_type = 'native' then concat('XLM:', lp.asset_b_code)
                else concat(lp.asset_a_code, ':', lp.asset_b_code)
            end as asset_pair
            , lp.asset_a_code
            , lp.asset_a_issuer
            , lp.asset_a_type
            , lp.asset_b_code
            , lp.asset_b_issuer
            , lp.asset_b_type
            , lp.asset_a_amount
            , lp.asset_b_amount
            , lp.last_modified_ledger
            , lp.ledger_entry_change
            , lp.closed_at
            , lp.deleted
            , lp.batch_run_date
            , row_number()
                over (
                    partition by lp.liquidity_pool_id
                    order by lp.last_modified_ledger desc, lp.ledger_entry_change desc
                ) as row_nr
        from {{ ref('stg_liquidity_pools') }} as lp
        where
            true
            -- TODO: change batch_run_date to closed_at once the table is repartitioned on closed_at
            and timestamp(batch_run_date) < timestamp(date('{{ var("batch_end_date") }}'))
        {% if is_incremental() %}
            and timestamp(batch_run_date) >= timestamp(date('{{ var("batch_start_date") }}'))
    {% endif %}

    )
select
    liquidity_pool_id
    , fee
    , trustline_count
    , pool_share_count
    , asset_pair
    , asset_a_code
    , asset_a_issuer
    , asset_a_type
    , asset_b_code
    , asset_b_issuer
    , asset_b_type
    , asset_a_amount
    , asset_b_amount
    , last_modified_ledger
    , ledger_entry_change
    , closed_at
    , deleted
    , batch_run_date
    , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
from current_lps
where row_nr = 1
