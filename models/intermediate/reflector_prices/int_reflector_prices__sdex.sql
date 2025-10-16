{{ config(
    materialized='table'
    )
}}

WITH data AS (
  SELECT 
    ledger_sequence, 
    closed_at, 
    ledger_key_hash,
    key_decoded, 
    val_decoded
  FROM {{ ref('contract_data_snapshot') }}
  WHERE contract_id = 'CALI2BYU2JE6WVRUFYTS6MSBNEHGJ35P4AVCZYF3B6QOE3QKOB2PLE6M'
    AND contract_key_type = 'ScValTypeScvLedgerKeyContractInstance'
),

parsed AS (
  SELECT
    closed_at AS updated_at,
    COALESCE(
      JSON_EXTRACT_SCALAR(item, '$.key.string'),
      JSON_EXTRACT_SCALAR(item, '$.key.symbol'),
      JSON_EXTRACT_SCALAR(item, '$.key.address')
    ) AS asset_id,
    'GC2M2UTZ57GSENZBTPMLPB6QSAL2USIPHMXSUCT2I3V24GYWF3EI6RFA' AS asset_issuer,  -- value of admin key
    COALESCE(
      JSON_EXTRACT_SCALAR(item, '$.val.address'),
      JSON_EXTRACT_SCALAR(item, '$.val.u32'),
      JSON_EXTRACT_SCALAR(item, '$.val.u64'),
      JSON_EXTRACT_SCALAR(item, '$.val.string')
    ) AS usd_price
  FROM data,
  UNNEST(JSON_EXTRACT_ARRAY(val_decoded, '$.contract_instance.storage')) AS item
)

SELECT *
FROM parsed
WHERE asset_id NOT IN (
  'admin',
  'assets',
  'base_asset',
  'decimals',
  'last_timestamp',
  'period',
  'resolution'
)
