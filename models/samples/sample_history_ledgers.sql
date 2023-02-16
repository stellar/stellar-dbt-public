{{ config(
    materialized='table'
    , cluster_by=["sequence", "closed_at"]
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
        from {{ source('test_crypto_stellar_2', 'history_ledgers') }}
        -- where batch_run_date between {batch_run_start} and {batch_run_finish}
    )
    
select *
from raw_table