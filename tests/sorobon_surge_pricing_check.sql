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
where closed_at >= current_timestamp - interval 1 hour
  -- inclusion fees over 100 stroops indicate surge pricing on the network
  and inclusion_fee_charged > 100
)

select 
if (
  (select count(*)
    from surge_pricing_check
  ) = 0,
  --Return when True:
  'Network is in normal pricing',
  -- Return Alert when False:
  ERROR('Network has entered surge pricing for Soroban'))
  ;
  select true; 
