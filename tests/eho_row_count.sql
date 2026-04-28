-- Strictly use enabled condition to restrict singular tests from running in dbt build tasks.
-- https://github.com/stellar/stellar-dbt-public/pull/95
{{ config(
    severity="error"
    , tags=["validate_eho_tables"]
    , enabled=var("is_singular_airflow_task") == "true"
    )
}}

-- enriched_history_operations is a 1:1 derivation of stg_history_operations
-- in the batch window. A row count mismatch indicates the mart silently
-- dropped operations during enrichment (faster, complementary to eho_by_ops
-- which finds the individual missing op_ids).

with eho_count as (
    select count(*) as cnt
    from {{ ref('enriched_history_operations') }}
    where closed_at >= timestamp(date('{{ var("batch_start_date") }}'))
        and closed_at < timestamp(date_add(date('{{ var("batch_end_date") }}'), interval 1 day))
)

, ops_count as (
    select count(*) as cnt
    from {{ ref('stg_history_operations') }}
    where closed_at >= timestamp(date('{{ var("batch_start_date") }}'))
        and closed_at < timestamp(date_add(date('{{ var("batch_end_date") }}'), interval 1 day))
)

select
    eho_count.cnt as eho_count
    , ops_count.cnt as operations_count
    , ops_count.cnt - eho_count.cnt as missing_count
from eho_count, ops_count
where eho_count.cnt != ops_count.cnt
