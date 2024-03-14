{{ 
    config(
        tags = ["current_state"],
        materialized = "incremental",
        unique_key = "liquidity_pool_id",
        cluster_by = ["asset_a_code", "asset_a_issuer", "asset_b_code", "asset_b_issuer"]
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
            , l.closed_at
            , lp.deleted
            , lp.batch_run_date
            , lp.batch_insert_ts
            , row_number()
            over (
                partition by lp.liquidity_pool_id
                order by lp.last_modified_ledger desc, lp.ledger_entry_change desc
            ) as row_nr
        from {{ ref('stg_liquidity_pools') }} as lp
        join {{ ref('stg_history_ledgers') }} as l
            on lp.last_modified_ledger = l.sequence

        {% if is_incremental() %}
            -- limit the number of partitions fetched
            where
                lp.batch_run_date >= date_sub(current_date(), interval 30 day)
                -- fetch the last week of records loaded
                and timestamp_add(lp.batch_insert_ts, interval 7 day)
                > (select max(t.upstream_insert_ts) from {{ this }} as t)
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
    , batch_insert_ts as upstream_insert_ts
    , current_timestamp() as batch_insert_ts
from current_lps
where row_nr = 1
