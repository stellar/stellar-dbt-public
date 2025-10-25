with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'liquidity_pools') }}
    )

    , liquidity_pool as (
        select
            liquidity_pool_id
            , type
            , fee
            , trustline_count
            , pool_share_count
            , asset_a_type
            , asset_a_code
            , asset_a_issuer
            , asset_a_id
            , asset_a.asset_contract_id as asset_a_contract_id
            , asset_a_amount
            , asset_b_type
            , asset_b_code
            , asset_b_issuer
            , asset_b_id
            , asset_b.asset_contract_id as asset_b_contract_id
            , asset_b_amount
            , last_modified_ledger
            , ledger_entry_change
            , deleted
            , batch_id
            , batch_run_date
            , closed_at
            , ledger_sequence
            , batch_insert_ts
            , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
        from raw_table
        left join {{ ref('stg_assets') }} as asset_a
            on raw_table.asset_a_code = asset_a.asset_code
            and raw_table.asset_a_issuer = asset_a.asset_issuer
            and raw_table.asset_a_type = asset_a.asset_type
        left join {{ ref('stg_assets') }} as asset_b
            on raw_table.asset_b_code = asset_b.asset_code
            and raw_table.asset_b_issuer = asset_b.asset_issuer
            and raw_table.asset_b_type = asset_b.asset_type
    )

select *
from liquidity_pool
