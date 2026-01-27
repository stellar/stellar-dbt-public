{% set meta_config = {
    "materialized": "incremental",
    "unique_key": ["key_hash"],
    "cluster_by": ["key_hash"],
    "tags": ["current_state"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

/* Finds the latest state of each ttl for contracts or wasms.
   Ranks each record (grain: one row per contract_id/contract_code_hash)) using
   the last modified ledger sequence number. */

with
    current_expiration as (
        select
            ttl.key_hash
            , ttl.live_until_ledger_seq
            , ttl.ledger_sequence
            , ttl.last_modified_ledger
            , ttl.ledger_entry_change
            , ttl.closed_at
            , ttl.deleted
            , ttl.batch_id
            , ttl.batch_run_date
        from {{ ref('stg_ttl') }} as ttl
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
                partition by ttl.key_hash
                order by ttl.closed_at desc
            )
        = 1
    )

select
    key_hash
    , live_until_ledger_seq
    , ledger_sequence
    , last_modified_ledger
    , ledger_entry_change
    , closed_at
    , deleted
    , batch_id
    , batch_run_date
    , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
from current_expiration
