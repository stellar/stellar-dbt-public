{# batch_size can be overridden (e.g. MICROBATCH_SIZE=month for backfills) without
   changing the table's day partitioning — see macros/bq_validate_microbatch_config.sql #}
{% set batch_size = var('microbatch_size', 'day') %}

{% set meta_config = {
    "materialized": "incremental",
    "incremental_strategy": "microbatch",
    "event_time": "closed_at",
    "batch_size": batch_size,
    "begin": "2015-09-30",
    "partition_by": {
        "field": "closed_at"
        , "data_type": "timestamp"
        , "granularity": "day"}
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}


with
    token_transfers as (
        select
            tt.transaction_hash
            , tt.transaction_id
            , tt.operation_id
            , tt.event_topic
            , tt.`from`
            , tt.`to`
            -- Original token transfers only built asset_code:asset_issuer, it dropped asset_type for all assets less XLM
            , replace(tt.asset, substr(tt.asset, 1, instr(tt.asset, ':')), '') as asset
            , tt.asset_type
            , tt.asset_code
            , tt.asset_issuer
            , safe_cast(sum(safe_cast(tt.amount_raw as numeric)) as string) as amount_raw
            -- should we be safe_casting decimal as int64 or something else here?
            , sum(safe_cast(tt.amount_raw as numeric) * pow(10, coalesce(-safe_cast(metadata.decimal as int64), -7))) as amount
            , tt.contract_id
            , tt.ledger_sequence
            , tt.closed_at
            , tt.to_muxed
            , tt.to_muxed_id
        -- microbatch auto-filters this ref to the batch window via event_time
        from {{ ref('stg_token_transfers_raw') }} as tt
        left join {{ ref('int_asset_metadata') }} as metadata
            on tt.contract_id = metadata.contract_id
        group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 13, 14, 15, 16, 17
    )
    , operations as (
        select
            op_id
            , `type`
            , type_string as event_type
            , coalesce(`type` in (24, 25, 26), false) as is_soroban
        from {{ ref('stg_history_operations') }}
        where
            -- join-side read only: batch_run_date (ETL ingestion date) can differ slightly
            -- from closed_at, so pad the batch window by a day on each side. Output rows
            -- are still bounded by the auto-filter on stg_token_transfers_raw.closed_at.
            {% if model.batch %}
                batch_run_date < datetime_add(datetime(timestamp('{{ model.batch.event_time_end }}')), interval 1 day)
                and batch_run_date >= datetime_sub(datetime(timestamp('{{ model.batch.event_time_start }}')), interval 1 day)
            {% else %}
                true
            {% endif %}
    )

select
    tt.transaction_hash
    , tt.transaction_id
    , tt.operation_id
    , tt.event_topic
    , op.event_type
    , tt.`from`
    , tt.`to`
    , tt.asset
    , tt.asset_type
    , tt.asset_code
    , tt.asset_issuer
    , tt.amount
    , tt.amount_raw
    , tt.contract_id
    , tt.ledger_sequence
    , tt.closed_at
    , tt.to_muxed
    , tt.to_muxed_id
    , op.is_soroban
    , sha256(concat(
        tt.transaction_hash, '|', coalesce(tt.operation_id, 0), '|', tt.contract_id, '|'
        , coalesce(tt.to, ''), '|', coalesce(tt.to_muxed, ''), '|', coalesce(tt.from, ''), '|', tt.event_topic
    )) as unique_key
from token_transfers as tt
left outer join operations as op
    on tt.operation_id = op.op_id
