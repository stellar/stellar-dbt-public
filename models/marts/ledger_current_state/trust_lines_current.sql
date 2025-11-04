{% set meta_config = {
    "materialized": "incremental",
    "unique_key": "unique_id",
    "cluster_by": ["asset_code", "asset_issuer"],
    "tags": ["current_state"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
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
        from {{ ref('stg_trust_lines') }} as tl

        where
            true
            -- TODO: change batch_run_date to closed_at once the table is repartitioned on closed_at
            and timestamp(batch_run_date) < timestamp(date('{{ var("batch_end_date") }}'))
        {% if is_incremental() %}
            and timestamp(batch_run_date) >= timestamp(date('{{ var("batch_start_date") }}'))
    {% endif %}
        qualify row_number()
            over (
                partition by tl.account_id, tl.asset_code, tl.asset_issuer, tl.liquidity_pool_id
                order by tl.last_modified_ledger desc, tl.ledger_entry_change desc
            )
        = 1
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
    , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
from current_tls
