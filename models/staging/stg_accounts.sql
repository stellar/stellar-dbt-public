{{ config(
    tags = ["enriched_history_operations"]
    )
}}

with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'accounts')}}
    )

    , accounts as (
        select
            account_id
            , balance
            , buying_liabilities
            , selling_liabilities
            , sequence_number
            , num_subentries
            , inflation_destination
            , flags
            , home_domain
            , master_weight
            , threshold_low
            , threshold_medium
            , threshold_high
            , last_modified_ledger
            , ledger_entry_change
            , deleted
            , sponsor
            , num_sponsored
            , num_sponsoring
            , sequence_ledger
            , sequence_time
            , batch_id
            , batch_run_date
            , batch_insert_ts
        from raw_table
    )

select *
from accounts
