-- Catches stale-baked-in scaling in int_token_transfer_enrichment. The stored
-- `amount` is computed at write time as amount_raw * 10^-decimal using whatever
-- int_asset_metadata returned at that moment. If int_asset_metadata had a gap
-- in decimal resolution when a row was materialized (e.g., contract metadata
-- wasn't yet ingested into contract_data_current), the row gets baked in with
-- the default 10^-7 fallback instead of the correct decimal. Later metadata
-- fixes don't retroactively update those historical rows.
--
-- This test recomputes amount against current metadata and fails on rows where
-- the stored value disagrees by more than a tolerance. Tolerance is high enough
-- to ignore float64 precision noise on large summed values but low enough to
-- catch genuine scaling regressions (which are typically off by 10^11 or more
-- when the wrong decimal is used).
--
-- Context: deJAAA/deJTRSY incident on 2026-05-15. See
-- POSTMORTEM_DEJAAA_DEJTRSY_2026-05-15.md in stellar-dbt for details.

{{ config(
    severity="error"
    , tags=["singular_test"]
    , meta={"alert_suppression_interval": 24}
    , enabled=(target.name == "prod" and var("is_singular_airflow_task") == "true")
    , alert_suppression_interval=24
    )
}}

with current_metadata as (
    select
        contract_id
        , safe_cast(`decimal` as int64) as decimal_int
    from {{ ref('int_asset_metadata') }}
)

, daily_compare as (
    select
        date(tt.closed_at) as day
        , tt.contract_id
        , sum(tt.amount) as stored_total
        , sum(safe_cast(tt.amount_raw as numeric) * pow(10, coalesce(-cm.decimal_int, -7))) as recomputed_total
    from {{ ref('int_token_transfer_enrichment') }} as tt
    left join current_metadata as cm
        on tt.contract_id = cm.contract_id
    where tt.closed_at >= timestamp('2024-02-01')
    group by 1, 2
)

select
    day
    , contract_id
    , stored_total
    , recomputed_total
    , abs(stored_total - recomputed_total) as abs_diff
from daily_compare
where abs(stored_total - recomputed_total) > 100
