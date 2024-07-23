{{
    config(
        tags = ["current_state"],
        materialized = "incremental",
        unique_key = "balance_id"
    )
}}
/* Returns the latest state of each claimable balance in the `claimable_balances` table.

    Rank all rows for a claimable balance by closed_at timestamp and pick the latest one.*/

with
    current_balance as (
        select
            cb.balance_id
            , cb.claimants
            , cb.asset_type
            , cb.asset_code
            , cb.asset_issuer
            , cb.asset_amount
            , cb.sponsor
            , cb.flags
            , cb.last_modified_ledger
            , cb.ledger_entry_change
            , cb.deleted
            , cb.batch_id
            , cb.batch_run_date
            , cb.batch_insert_ts
            , cb.closed_at
            , cb.ledger_sequence
            , row_number()
                over (
                    partition by cb.balance_id
                    order by cb.closed_at desc
                ) as rn
        from {{ ref('stg_claimable_balances') }} as cb
        {% if is_incremental() %}
            -- limit the number of partitions fetched incrementally
            where
                cb.closed_at >= timestamp_sub(current_timestamp(), interval 30 day)
                -- fetch the last week of records loaded
                and timestamp_add(cb.batch_insert_ts, interval 7 day)
                > (select max(t.upstream_insert_ts) from {{ this }} as t)
        {% endif %}
    )

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
    , ledger_entry_change
    , deleted
    , batch_id
    , batch_run_date
    , closed_at
    , ledger_sequence
    , batch_insert_ts as upstream_insert_ts
    , current_timestamp() as batch_insert_ts
from current_balance
where rn = 1
