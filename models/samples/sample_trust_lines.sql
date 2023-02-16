{{ config(
    materialized='table'
    , cluster_by= ["account_id", "last_modified_ledger"]
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
        from {{ source('test_crypto_stellar_2', 'trust_lines') }}
        -- where batch_run_date between {batch_run_start} and {batch_run_finish}
    )
    
select *
from raw_table