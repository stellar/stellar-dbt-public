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
        from {{ ref('stg_contract_data') }} as cd
        where
            true
            -- Need to add/subtract one day to the window boundaries
            -- because this model runs at 30 min increments.
            -- Without the additional date buffering the following would occur
            -- * batch_start_date == '2025-01-01 01:00:00' --> '2025-01-01'
            -- * batch_end_date == '2025-01-01 01:30:00' --> '2025-01-01'
            -- * '2025-01-01 <= closed_at < '2025-01-01' would never have any data to processes
            and closed_at < timestamp(date_add(date('{{ var("batch_end_date") }}'), interval 1 day))
        {% if is_incremental() %}
            -- The extra day date_sub is useful in the case the first scheduled run for a day is skipped
            -- because the DAG is configured with catchup=false
            and closed_at >= timestamp(date_sub(date('{{ var("batch_start_date") }}'), interval 1 day))
    {% endif %}
        qualify row_number()
            over (
                partition by cd.contract_id, cd.ledger_key_hash
                order by cd.closed_at desc
            )
        = 1
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
