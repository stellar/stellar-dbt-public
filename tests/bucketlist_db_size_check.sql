-- Strictly use enabled condition to restrict singular tests from running in dbt build tasks.
-- https://github.com/stellar/stellar-dbt-public/pull/95
{{ config(
    severity="error"
    , tags=["singular_test"]
    , enabled=(target.name == "prod" and var("is_singular_airflow_task") == "true")
    )
}}

with bucket_max_size as (
  select
    bucket_list_target_size_bytes
  from {{ ref('config_settings_current') }}
  where true
    and config_setting_id = 2
)
, bucketlist_db_size as (
  select sequence,
    closed_at,
    total_byte_size_of_bucket_list / 1000000000 as bl_db_gb
  from {{ ref('stg_history_ledgers') }}
  where closed_at >= TIMESTAMP_SUB('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL 1 HOUR )
  -- alert when the bucketlist has grown larger than 1 gb from bucket_list_target_size_bytes
    and total_byte_size_of_bucket_list > (select bucket_list_target_size_bytes - 1000000000 from bucket_max_size)
)

select * from bucketlist_db_size
