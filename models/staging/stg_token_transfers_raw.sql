with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'token_transfers_raw') }}
    )

    , token_transfers_raw as (
        select
            *
            , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
        from raw_table
    )

select *
from token_transfers_raw
