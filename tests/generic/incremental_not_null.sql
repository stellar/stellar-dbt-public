{% test incremental_not_null(model, column_name, date_column_name, greater_than_equal_to, condition) %}

    {{ config(severity = 'error') }}
    {% set date_column_name = date_column_name | default('closed_at') %}
    {% set greater_than_equal_to = greater_than_equal_to | default('') %}
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
        -- Incremental mode: filter to batch window [batch_start_date, batch_end_date)
        select {{ column_name }}
        from {{ model }}
        where true
        and {{ column_name }} is null
        {% if greater_than_equal_to != '' %}
        -- Deprecated: greater_than_equal_to widens the lower bound
        and TIMESTAMP({{ date_column_name }}) >= TIMESTAMP_SUB(TIMESTAMP('{{ var("batch_start_date") }}'), INTERVAL {{ greater_than_equal_to }} )
        {% else %}
        and TIMESTAMP({{ date_column_name }}) >= TIMESTAMP('{{ var("batch_start_date") }}')
        {% endif %}
        and TIMESTAMP({{ date_column_name }}) < TIMESTAMP('{{ var("batch_end_date") }}')

        {% if condition != '' %}
        and {{ condition }}
        {% endif %}
    {% endif %}

{% endtest %}
