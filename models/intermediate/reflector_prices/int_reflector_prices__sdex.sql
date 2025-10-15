{{ config(
    materialized='incremental'
    )
}}

SELECT ledger_sequence, closed_at, ledger_key_hash, key_decoded, val_decoded
FROM {{ ref('contract_data_snapshot') }} 
where contract_id = 'CALI2BYU2JE6WVRUFYTS6MSBNEHGJ35P4AVCZYF3B6QOE3QKOB2PLE6M' 
and contract_key_type = 'ScValTypeScvLedgerKeyContractInstance'

