{{
    config(
        tags = ["current_state"],
        materialized = "incremental",
        unique_key = "unique_id",
        cluster_by = ["asset_code", "asset_issuer"]
    )
}}

/* Finds the latest state of each trust line in the `trust_lines` table.
   Ranks each record (grain: one row per trust line) using
   last modified ledger sequence number. View includes all trust lines.
   (Deleted and Existing). View matches the Horizon snapshotted state tables. */
with
    current_tls as (
        select
            tl.account_id
            , tl.asset_code
            , tl.asset_issuer
            , tl.asset_type
            , tl.liquidity_pool_id
            , tl.balance
            , tl.buying_liabilities
            , tl.selling_liabilities
            , tl.flags
            , tl.sponsor
            , tl.trust_line_limit
            , tl.last_modified_ledger
            , tl.ledger_entry_change
            , tl.closed_at
            , tl.deleted
            -- table only has natural keys, creating a primary key
            , concat(tl.account_id, '-', tl.asset_code, '-', tl.asset_issuer, '-', tl.liquidity_pool_id
            ) as unique_id
            , tl.batch_run_date
            , tl.batch_insert_ts
            , row_number()
                over (
                    partition by tl.account_id, tl.asset_code, tl.asset_issuer, tl.liquidity_pool_id
                    order by tl.last_modified_ledger desc, tl.ledger_entry_change desc
                ) as row_nr
        from {{ ref('stg_trust_lines') }} as tl
        {% if is_incremental() %}
            -- limit the number of partitions fetched incrementally
            where
                tl.closed_at >= timestamp_sub(current_timestamp(), interval 7 day)
        {% endif %}

    )
select
    account_id
    , asset_code
    , asset_issuer
    , asset_type
    , liquidity_pool_id
    , balance
    , buying_liabilities
    , selling_liabilities
    , flags
    , sponsor
    , trust_line_limit
    , last_modified_ledger
    , ledger_entry_change
    , closed_at
    , deleted
    , unique_id
    , batch_run_date
    , batch_insert_ts as upstream_insert_ts
    , current_timestamp() as batch_insert_ts
from current_tls
where row_nr = 1
