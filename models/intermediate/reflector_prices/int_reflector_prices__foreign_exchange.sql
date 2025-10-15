{{ config(
    materialized='incremental'
    )
}}

SELECT ledger_sequence, closed_at, ledger_key_hash, key_decoded, val_decoded
FROM {{ ref('contract_data_snapshot') }} 
where contract_id = 'CBKGPWGKSKZF52CFHMTRR23TBWTPMRDIYZ4O2P5VS65BMHYH4DXMCJZC' 
and contract_key_type = 'ScValTypeScvLedgerKeyContractInstance'

