{% test incremental_expression_is_true(model, column_name, date_column_name, greater_than_equal_to, less_than_equal_to, condition, expression) %}

    {{ config(severity = 'error') }}
    {% set condition = condition | default('') %}
    {% set date_column_name = date_column_name | default('closed_at') %}
    {% set greater_than_equal_to = greater_than_equal_to | default('2 day') %}
    {% set less_than_equal_to = less_than_equal_to | default('') %}
    {% set expression = expression | default('') %}

    select
        {{ column_name }}
    from {{ model }}
        where true
        and not({{ column_name }} {{ expression }})

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

{% endtest %}
