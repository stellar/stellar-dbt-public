{{ config(
    materialized='incremental'
    )
}}

SELECT ledger_sequence, closed_at, ledger_key_hash, key_decoded, val_decoded
FROM {{ ref('contract_data_snapshot') }} 
where contract_id = 'CAFJZQWSED6YAWZU3GWRTOCNPPCGBN32L7QV43XX5LZLFTK6JLN34DLN' 
and contract_key_type = 'ScValTypeScvLedgerKeyContractInstance'

