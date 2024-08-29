{% test incremental_unique_combination_of_columns(model, date_column_name, greater_than_equal_to, less_than_equal_to, condition, combination_of_columns=[]) %}

    {# Convert columns list into a comma-separated string for SQL #}

    {{ config(severity = 'error') }}
    {% set condition = condition | default('') %}
    {% set date_column_name = date_column_name | default('closed_at') %}
    {% set greater_than_equal_to = greater_than_equal_to | default('2 day') %}
    {% set less_than_equal_to = less_than_equal_to | default('') %}
    {% set columns_list = combination_of_columns | join(', ') %}

    with validation_errors as (

        select
            {{ columns_list }}
        from (
            select {{ columns_list }}
            from {{ model }}
            {% if flags.FULL_REFRESH %}
                -- Full refresh mode: no date filter, just check for null values
                {% if condition != '' %}
                where {{ condition }}
                {% endif %}
            {% else %}
                where true
                and TIMESTAMP({{ date_column_name }}) >= TIMESTAMP_SUB('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL {{ greater_than_equal_to }} )

                {% if less_than_equal_to != '' %}
                and TIMESTAMP({{ date_column_name }}) <= TIMESTAMP_ADD('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL {{ less_than_equal_to }} )
                {% endif %}

                {% if condition != '' %}
                and {{ condition }}
                {% endif %}
            {% endif %}
        ) dbt_subquery
        group by {{ columns_list }}
        having count(*) > 1
    )

    select *
    from validation_errors

{% endtest %}
