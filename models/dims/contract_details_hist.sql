{{ config(materialized = 'table') }}

select
    'dummy_contract_id' as contract_id
    , 'dummy_ledger_key_hash' as ledger_key_hash
    , current_timestamp() as start_date
    , current_timestamp() as end_date
    , true as is_current
where false
