{{ config(
    severity="error"
    , tags=["singular_test"]
    )
}}

with bucketlist_db_size as (
  select sequence,
    closed_at,
    total_byte_size_of_bucket_list / 1000000000 as bl_db_gb
  from {{ source('crypto_stellar', 'history_ledgers') }}
  where closed_at >= TIMESTAMP_SUB('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL 1 HOUR )
  -- alert when the bucketlist has grown larger than 12 gb
    and total_byte_size_of_bucket_list / 1000000000 >= 12
)

select * from bucketlist_db_size
