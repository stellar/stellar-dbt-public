-- For contract tokens that publish both an asset_code via SAC transfer events
-- and a SEP-41 symbol in their contract storage metadata, the two should agree.
-- A mismatch indicates either a misconfigured SAC, a custom contract impersonating
-- a recognized asset, or a data-quality issue worth investigating.
--
-- Known exception: the XLM SAC contract publishes "native" as its symbol while
-- our staging layer rewrites the asset_code to "XLM" for ergonomics.
-- This was confirmed against production data on 2026-05-06; no other mismatches existed.
{{ config(severity='warn') }}

select
    contract_id
    , asset_code
    , symbol
from {{ ref('int_contract_asset_codes') }}
where asset_code_source = 'sac'
    and symbol is not null
    and asset_code != symbol
    and contract_id != 'CAS3J7GYLGXMF6TDJBBYYSE3HQ6BBSMLNUQ34T6TZMYMW2EVH34XOWMA'
