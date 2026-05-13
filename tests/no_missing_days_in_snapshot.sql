{{ config(
    severity="error"
    , tags=["no_missing_days_in_snapshot"]
    , enabled=var("is_singular_airflow_task") == "true"
    )
}}

{% set table_name = var('table_name', none) %}
{% if table_name %}
    {% set tables = [table_name] %}
{% else %}
    {% set tables = [
        'accounts_snapshot',
        'contract_data_snapshot',
        'evicted_keys_snapshot',
        'liquidity_pools_snapshot',
        'reflector_prices_data_cex_snapshot',
        'reflector_prices_data_fex_snapshot',
        'reflector_prices_data_sdex_snapshot',
        'trustlines_snapshot',
    ] %}
{% endif %}

WITH all_dates AS (
  SELECT dates AS day
  FROM UNNEST(
    GENERATE_DATE_ARRAY(
      DATE_SUB(DATE('{{ var("batch_start_date") }}'), INTERVAL 6 MONTH),
      DATE('{{ var("batch_end_date") }}')
    )
  ) AS dates
)

SELECT
  table_name,
  start_date,
  end_date,
  missing_days
FROM (

  {% for table in tables %}
    SELECT
      '{{ table }}' AS table_name,
      MIN(day) AS start_date,
      MAX(day) AS end_date,
      DATE_DIFF(MAX(day), MIN(day), DAY) + 1 AS missing_days
    FROM (
      SELECT
        day,
        DATE_SUB(day, INTERVAL ROW_NUMBER() OVER (ORDER BY day) DAY) AS grp
      FROM (
        SELECT DISTINCT day
        FROM all_dates
        WHERE day NOT IN (
          SELECT DATE(valid_from)
          FROM {{ ref(table) }}
        )
      )
    )
    GROUP BY grp

    {% if not loop.last %}
      UNION ALL
    {% endif %}
  {% endfor %}

)
ORDER BY end_date DESC
