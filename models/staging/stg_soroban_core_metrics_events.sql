with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'history_contract_events') }}
    )

    , soroban_core_metrics_events as (
        select
            closed_at
            , ledger_sequence
            , transaction_hash
            , json_value(topics_decoded, '$[1].symbol') as metric_key
            , safe_cast(json_value(data_decoded, '$.u64') as int64) as metric_value                                                                                                             
            , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
        from raw_table
        where type_string = 'ContractEventTypeDiagnostic'
          and json_value(topics_decoded, '$[0].symbol') = 'core_metrics'
    )
  
select *
from soroban_core_metrics_events