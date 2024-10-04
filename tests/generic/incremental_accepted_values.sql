{% test incremental_accepted_values(model, column_name, date_column_name, greater_than_equal_to, less_than_equal_to, condition, values=[], quote=false) %}

    {{ config(severity = 'error') }}
    {% set condition = condition | default('') %}
    {% set date_column_name = date_column_name | default('closed_at') %}
    {% set greater_than_equal_to = greater_than_equal_to | default('2 day') %}
    {% set less_than_equal_to = less_than_equal_to | default('') %}
    {% if quote %}
        {% set values = values | map(attribute='string') | join(', ') %}
    {% else %}
        {% set values = values | join(', ') %}
    {% endif %}

    with all_values as (

        select
            {{ column_name }} as value_field,
            count(*) as n_records

        from {{ model }}
        where true

        {% if condition != '' %}
            and {{ condition }}
        {% endif %}

        {% if flags.FULL_REFRESH %}
            -- Full refresh mode: no date filter, just check for null values
            -- do nothing
        {% else %}
            -- Incremental mode: filter records based on greater_than_equal_to
            and TIMESTAMP({{ date_column_name }}) >= TIMESTAMP_SUB('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL {{ greater_than_equal_to }} )

            {% if less_than_equal_to != '' %}
                and TIMESTAMP({{ date_column_name }}) <= TIMESTAMP_ADD('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL {{ less_than_equal_to }} )
            {% endif %}

        {% endif %}

        group by {{ column_name }}

    )

    select value_field
    from all_values
    where value_field not in (
        {{ values }}
    )

{% endtest %}
