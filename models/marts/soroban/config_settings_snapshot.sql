{% set meta_config = {
    "tags": ["soroban", "network_stats"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

{% set columns = adapter.get_columns_in_relation(source('crypto_stellar', 'config_settings')) %}

{% set excluded_cols = [
    'config_setting_id',
    'contract_cost_params_cpu_insns',
    'contract_cost_params_mem_bytes',
    'deleted',
    'batch_id',
    'batch_run_date',
    'batch_insert_ts',
    'ledger_sequence',
    'bucket_list_size_window',
    'closed_at',
    'airflow_start_ts'
] %}

{% set filtered_cols = [] %}
{% for col in columns %}
    {% if col.name not in excluded_cols %}
        {% do filtered_cols.append(col) %}
    {% endif %}
{% endfor %}

with
    unpivoted as (

        {% for metric in filtered_cols %}
            select
                '{{ metric.name }}' as metric
                , {{ metric.name }} as val
                , closed_at as valid_from
            from {{ ref('stg_config_settings') }}
            where {{ metric.name }} <> 0
            group by 1, 2, 3
            {% if not loop.last %}
                union all
            {% endif %}
        {% endfor %}
    )

    , scd as (
        select
            *
            , valid_to is null as is_current_setting
        from (
            select
                metric as config_setting_name
                , val as setting_value
                , valid_from
                , lead(valid_from) over (partition by metric order by valid_from) as valid_to
            from unpivoted
        )
    )

select
    scd.config_setting_name
    , scd.setting_value
    , scd.valid_from
    , scd.valid_to
    , scd.is_current_setting
    , m.core_metric
    , m.grain
    , m.is_resource_utilization_relevant
    , m.pretty_config_name
from scd
left join {{ ref('config_setting_to_metrics_mapping') }} as m
    on scd.config_setting_name = m.config_setting_description
order by scd.config_setting_name, scd.valid_from
