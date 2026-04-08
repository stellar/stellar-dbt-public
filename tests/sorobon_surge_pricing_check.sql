-- Strictly use enabled condition to restrict singular tests from running in dbt build tasks.
-- https://github.com/stellar/stellar-dbt-public/pull/95
{{ config(
    severity="warn"
    , tags=["singular_test"]
    , meta={"alert_suppression_interval": 24}
    , enabled=false
    , alert_suppression_interval=24
    )
}}

with surge_pricing_check as (
  select inclusion_fee_charged,
    ledger_sequence,
    closed_at
from {{ ref('enriched_history_operations_soroban') }}
where closed_at >= TIMESTAMP('{{ var("batch_start_date") }}')
  and closed_at < TIMESTAMP('{{ var("batch_end_date") }}')
  -- inclusion fees over 100 stroops indicate surge pricing on the network
  and inclusion_fee_charged > 100
)

select * from surge_pricing_check
