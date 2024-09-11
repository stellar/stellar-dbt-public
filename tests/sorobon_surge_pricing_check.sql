{{ config(
    severity="warn"
    , tags=["singular_test"]
    )
}}

with surge_pricing_check as (
  select inclusion_fee_charged,
    ledger_sequence,
    closed_at
from `crypto-stellar.crypto_stellar_dbt.enriched_history_operations_soroban`
where closed_at >= TIMESTAMP_SUB('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL 1 HOUR )
  -- inclusion fees over 100 stroops indicate surge pricing on the network
  and inclusion_fee_charged > 100
)

select * from surge_pricing_check;