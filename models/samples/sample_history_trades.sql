{{ config(
    materialized='table'
    , cluster_by= ["history_operation_id", "ledger_closed_at"]
    , partition_by={
        "field": "batch_run_date"
        , "data_type": "datetime"
        , "granularity": "month"
    }
    ) 
}}

with 
    raw_table as (
        select 
            *
        from {{ source('test_crypto_stellar_2', 'history_trades') }}
        -- where batch_run_date between {batch_run_start} and {batch_run_finish}
    )
    
select *
from raw_table