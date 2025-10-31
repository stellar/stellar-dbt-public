{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["unique_id"],
    "cluster_by": ["contract_id"],
    "tags": ["current_state"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

/* Finds the latest state of each contract data entry.
   Ranks each record (grain: one row per contract_id + ledger_key_hash)) using
   the last modified ledger sequence number. */

with
    current_data as (
        select
            cd.contract_id
            , cd.contract_key_type
            , cd.contract_durability
            , cd.asset_code
            , cd.asset_issuer
            , cd.asset_type
            , cd.balance_holder
            , cd.balance
            , cd.last_modified_ledger
            , cd.ledger_entry_change
            , cd.closed_at
            , cd.deleted
            , cd.batch_id
            , cd.batch_run_date
            , cd.ledger_sequence
            , cd.ledger_key_hash
            , cd.key
            , cd.key_decoded
            , cd.val
            , cd.val_decoded
            , cd.contract_data_xdr
            , concat(cd.contract_id, '-', cd.ledger_key_hash) as unique_id
            , row_number()
                over (
                    partition by cd.contract_id, cd.ledger_key_hash
                    order by cd.closed_at desc
                ) as rn
        from {{ ref('stg_contract_data') }} as cd
        where
            true
            and closed_at < timestamp(date('{{ var("batch_end_date") }}'))
        {% if is_incremental() %}
            and closed_at >= timestamp(date('{{ var("batch_start_date") }}'))
    {% endif %}
    )

select
    contract_id
    , contract_key_type
    , contract_durability
    , asset_code
    , asset_issuer
    , asset_type
    , balance_holder
    , balance
    , last_modified_ledger
    , ledger_entry_change
    , ledger_sequence
    , ledger_key_hash
    , key
    , key_decoded
    , val
    , val_decoded
    , contract_data_xdr
    , closed_at
    , deleted
    , batch_id
    , batch_run_date
    , unique_id
    , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
from current_data
where rn = 1
