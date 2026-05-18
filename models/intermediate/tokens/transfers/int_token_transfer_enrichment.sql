{% set meta_config = {
    "materialized": "incremental",
    "unique_key": "unique_key",
    "incremental_strategy": "merge",
    "partition_by": {
        "field": "closed_at"
        , "data_type": "timestamp"
        , "granularity": "day"},
    "incremental_predicates": ["DBT_INTERNAL_DEST.closed_at >= timestamp_sub(timestamp(date('" ~ var('batch_start_date') ~ "')), interval 1 day)"]
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
        from {{ ref('stg_token_transfers_raw') }} as tt
        left join {{ ref('int_asset_metadata') }} as metadata
            on tt.contract_id = metadata.contract_id
        where
            tt.closed_at < timestamp(date_add(date('{{ var("batch_end_date") }}'), interval 1 day))
            {% if is_incremental() %}
                and tt.closed_at >= timestamp(date_sub(date('{{ var("batch_start_date") }}'), interval 1 day))
            {% endif %}
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
            batch_run_date < datetime(date_add(date('{{ var("batch_end_date") }}'), interval 1 day))
            {% if is_incremental() %}
                and batch_run_date >= datetime(date_sub(date('{{ var("batch_start_date") }}'), interval 1 day))
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
