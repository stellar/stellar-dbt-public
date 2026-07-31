{% set batch_size = microbatch_batch_size() %}
{% set begin = microbatch_begin('2015-09-30') %}

{% set meta_config = {
    "materialized": "incremental",
    "incremental_strategy": "microbatch",
    "event_time": "closed_at",
    "batch_size": batch_size,
    "concurrent_batches": true,
    "begin": begin,
    "partition_by": {
        "field": "closed_at"
        , "data_type": "timestamp"
        , "granularity": "day"
        , "copy_partitions": true},
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
            -- For contract tokens that don't expose asset_code on transfer events, fall back to
            -- int_asset_metadata which coalesces with SEP-41 symbol metadata (null when neither
            -- a SAC asset_code nor a SEP-41 symbol is available).
            , coalesce(nullif(tt.asset_code, ''), ac.asset_code) as asset_code
            , tt.asset_issuer
            , safe_cast(sum(safe_cast(tt.amount_raw as numeric)) as string) as amount_raw
            -- should we be safe_casting decimal as int64 or something else here?
            , sum(safe_cast(tt.amount_raw as numeric) * pow(10, coalesce(-safe_cast(ac.decimal as int64), -7))) as amount
            , tt.contract_id
            , tt.ledger_sequence
            , tt.closed_at
            , tt.to_muxed
            , tt.to_muxed_id
        from {{ ref('stg_token_transfers_raw') }} as tt
        left join {{ ref('int_asset_metadata') }} as ac
            on tt.contract_id = ac.contract_id
        group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 13, 14, 15, 16, 17
    )
    , operations as (
        select
            op_id
            , `type`
            , type_string as event_type
            , coalesce(`type` in (24, 25, 26), false) as is_soroban
        from {{ ref('stg_history_operations') }}
        {% if model.batch %}
            -- history_operations is partitioned on batch_run_date, so the microbatch
            -- closed_at filter alone cannot prune it. batch_run_date always falls within
            -- a day of closed_at, so this buffered range restores partition pruning
            -- without changing which rows qualify.
            where
                batch_run_date >= datetime_sub(datetime(timestamp('{{ model.batch.event_time_start }}')), interval 1 day)
                and batch_run_date < datetime_add(datetime(timestamp('{{ model.batch.event_time_end }}')), interval 1 day)
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
