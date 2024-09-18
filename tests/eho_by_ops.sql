-- Strictly use enabled condition to restrict singular tests from running in dbt build tasks.
-- https://github.com/stellar/stellar-dbt-public/pull/95
{{ config(
    severity="error"
    , tags=["singular_test"]
    , meta={"alert_suppression_interval": 24}
    , enabled=(target.name == "prod" and var("is_singular_airflow_task") == "true")
    )
}}

-- Enriched_history_operations table is dependent on the
-- history_operations table to load. It is assumed that
-- any id present in the upstream table should be loaded in
-- the downstream. If records are not present, alert the team.
WITH find_missing AS (
  SELECT op.op_id,
    op.batch_run_date,
    op.batch_id
  FROM {{ ref('stg_history_operations') }} op
  LEFT OUTER JOIN {{ ref('enriched_history_operations') }} eho
    ON op.op_id = eho.op_id
  WHERE eho.op_id IS NULL
    -- Scan only the last 24 hours of data. Alert runs intraday so failures
    -- are caught and resolved quickly.
    AND TIMESTAMP(op.batch_run_date) >= TIMESTAMP_SUB('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL 1 DAY )
    AND TIMESTAMP(op.batch_run_date) < TIMESTAMP_SUB('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL 1 HOUR )
),
find_max_batch AS (
  SELECT MAX(batch_run_date) AS max_batch
  FROM {{ ref('stg_history_operations') }}
  WHERE TIMESTAMP(batch_run_date) >= TIMESTAMP_SUB('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL 1 DAY )
    AND TIMESTAMP(batch_run_date) < TIMESTAMP_SUB('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL 1 HOUR )
)
SELECT batch_run_date,
    batch_id,
    count(*)
FROM find_missing
-- Account for delay in loading history_operations table prior to
-- enriched_history_operations table being loaded.
WHERE batch_run_date != (SELECT max_batch FROM find_max_batch)
GROUP BY 1, 2
ORDER BY 1
