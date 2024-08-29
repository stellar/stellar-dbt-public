{% test incremental_not_null(model, column_name, date_column_name, greater_than_equal_to, less_than_equal_to, condition) %}

    {{ config(severity = 'error') }}
    {% set date_column_name = date_column_name | default('closed_at') %}
    {% set greater_than_equal_to = greater_than_equal_to | default('2 day') %}
    {% set less_than_equal_to = less_than_equal_to | default('') %}
    {% set condition = condition | default('') %}

    {% if flags.FULL_REFRESH %}
        -- Full refresh mode: no date filter, just check for null values
        select {{ column_name }}
        from {{ model }}
        where true
        and {{ column_name }} is null

        {% if condition != '' %}
        and {{ condition }}
        {% endif %}

    {% else %}
        -- Incremental mode: filter records based on greater_than_equal_to
        select {{ column_name }}
        from {{ model }}
        where true
        and {{ column_name }} is null
        and TIMESTAMP({{ date_column_name }}) >= TIMESTAMP_SUB('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL {{ greater_than_equal_to }} )

        {% if less_than_equal_to != '' %}
        and TIMESTAMP({{ date_column_name }}) <= TIMESTAMP_ADD('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL {{ less_than_equal_to }} )
        {% endif %}

        {% if condition != '' %}
        and {{ condition }}
        {% endif %}
    {% endif %}

{% endtest %}
