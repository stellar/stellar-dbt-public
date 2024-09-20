{{ config(
    materialized = 'view',
    tags = ["soroban_analytics"],
    enabled = true,
    tests = {
        'unique': {
            'column_name': 'ledger_key_hash'
        },
        'not_null': {
            'column_name': 'ledger_key_hash'
        }
    }
) }}

{% set target_table_query %}
    SELECT COUNT(*) AS tgt_row_count FROM {{ ref('contract_details_hist') }}
{% endset %}

{% set results = run_query(target_table_query) %}

{% if execute %}
    {% set is_empty_target_table = (results.columns[0].values()[0] == 0) %}
{% else %}
    {% set is_empty_target_table = false %}
{% endif %}

with
    contract_data as (
        select
            cd.contract_id
            , cd.ledger_key_hash
            , cd.contract_key_type
            , cd.contract_durability
            , cd.last_modified_ledger
            , cd.ledger_entry_change
            , cd.ledger_sequence
            , cd.asset_code
            , cd.asset_issuer
            , cd.asset_type
            , cd.balance
            , cd.balance_holder
            , cd.deleted
            , cd.closed_at
            , cd.batch_insert_ts
            , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
            , cd.batch_id
            , cd.batch_run_date
            , row_number() over (partition by cd.ledger_key_hash order by cd.closed_at desc) as row_num
        from
            {{ source('crypto_stellar', 'contract_data') }} as cd

        {% if is_empty_target_table %}
        -- No WHERE condition here, as we want to pull all records
        {% elif var('recovery', 'False') == 'True' %}
        {% if var('recovery_type', 'SingleDay') == 'SingleDay' %}
            WHERE DATE(cd.closed_at) = '{{ var("recovery_date") }}'
        {% elif var('recovery_type', 'Range') == 'Range' %}
            WHERE DATE(cd.closed_at) BETWEEN '{{ var("recovery_start_day") }}' AND '{{ var("recovery_end_day") }}'
        {% elif var('recovery_type', 'Full') == 'Full' %}
            -- No WHERE condition for full recovery, as we want all data
        {% endif %}
    {% else %}
        WHERE
            timestamp(cd.closed_at) < timestamp_add(timestamp('{{ var("airflow_start_timestamp") }}'), interval 2 hour)
            AND timestamp(cd.closed_at) >= timestamp_sub(timestamp('{{ var("airflow_start_timestamp") }}'), interval 4 hour)
    {% endif %}
    )

    , ttl_data as (
        select
            ttl.key_hash
            , ttl.closed_at as ttl_closed_at
            , ttl.live_until_ledger_seq
            , ttl.deleted as ttl_deleted
            , row_number() over (partition by ttl.key_hash order by ttl.closed_at desc) as row_num
        from
            {{ source('crypto_stellar', 'ttl') }} as ttl

        {% if is_empty_target_table %}
        -- No WHERE condition here, as we want to pull all records
        {% elif var('recovery', 'False') == 'True' %}
        {% if var('recovery_type', 'SingleDay') == 'SingleDay' %}
            WHERE DATE(ttl.closed_at) = '{{ var("recovery_date") }}'
        {% elif var('recovery_type', 'Range') == 'Range' %}
            WHERE DATE(ttl.closed_at) BETWEEN '{{ var("recovery_start_day") }}' AND '{{ var("recovery_end_day") }}'
        {% elif var('recovery_type', 'Full') == 'Full' %}
            -- No WHERE condition for full recovery, as we want all data
        {% endif %}
    {% else %}
        WHERE
            timestamp(ttl.closed_at) < timestamp_add(timestamp('{{ var("airflow_start_timestamp") }}'), interval 2 hour)
            AND timestamp(ttl.closed_at) >= timestamp_sub(timestamp('{{ var("airflow_start_timestamp") }}'), interval 4 hour)
    {% endif %}
    )

    , derived_data as (
        select
            contract_id
            , min(case when ledger_entry_change = 0 and contract_key_type = 'ScValTypeScvLedgerKeyContractInstance' then closed_at end)
                as contract_create_ts
            , max(case when ledger_entry_change = 1 then closed_at end) as contract_updated_ts
            , max(case when ledger_entry_change = 2 and deleted = true then closed_at end) as contract_delete_ts
        from {{ source('crypto_stellar', 'contract_data') }}
        group by contract_id
    )

    , source_data as (
        select
            cd.contract_id
            , cd.ledger_key_hash
            , cd.contract_key_type
            , cd.contract_durability
            , cd.last_modified_ledger
            , cd.ledger_entry_change
            , cd.ledger_sequence
            , cd.asset_code
            , cd.asset_issuer
            , cd.asset_type
            , cd.balance
            , cd.balance_holder
            , cd.deleted
            , cd.closed_at
            , ttl.key_hash
            , ttl.ttl_closed_at
            , ttl.live_until_ledger_seq
            , ttl.ttl_deleted
            , cd.batch_insert_ts
            , cd.airflow_start_ts
            , cd.batch_id
            , cd.batch_run_date
        from
            contract_data as cd
        left join
            ttl_data as ttl
            on
            cd.ledger_key_hash = ttl.key_hash
        where
            cd.row_num = 1  -- Only the latest record per key_hash from contract_data
            and (ttl.row_num = 1 or ttl.row_num is null)  -- Only the latest record from ttl, if available
    )

select
    sd.contract_id
    , sd.ledger_key_hash
    , sd.contract_key_type
    , sd.contract_durability
    , dd.contract_create_ts
    , dd.contract_updated_ts
    , dd.contract_delete_ts
    , sd.last_modified_ledger
    , sd.ledger_entry_change
    , sd.ledger_sequence
    , sd.asset_code
    , sd.asset_issuer
    , sd.asset_type
    , sd.balance
    , sd.balance_holder
    , sd.deleted
    , sd.closed_at
    , sd.key_hash
    , sd.ttl_closed_at
    , sd.live_until_ledger_seq
    , sd.ttl_deleted
    , sd.batch_insert_ts
    , sd.airflow_start_ts
    , sd.batch_id
    , sd.batch_run_date
    , current_timestamp() as dw_load_ts
from source_data as sd
left join derived_data as dd on sd.contract_id = dd.contract_id
order by
    sd.contract_id, sd.closed_at
