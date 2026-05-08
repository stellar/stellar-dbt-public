{% test incremental_expression_is_true(model, column_name, date_column_name, greater_than_equal_to, condition, expression) %}

    {{ config(severity = 'error') }}
    {% set condition = condition | default('') %}
    {% set date_column_name = date_column_name | default('closed_at') %}
    {% set greater_than_equal_to = greater_than_equal_to | default('') %}
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
        -- Full refresh mode: no date filter
        -- do nothing
    {% else %}
        -- Incremental mode: filter to batch window [batch_start_date, batch_end_date)
        {% if greater_than_equal_to != '' %}
            -- Deprecated: greater_than_equal_to widens the lower bound
            and TIMESTAMP({{ date_column_name }}) >= TIMESTAMP_SUB(TIMESTAMP('{{ var("batch_start_date") }}'), INTERVAL {{ greater_than_equal_to }} )
        {% else %}
            and TIMESTAMP({{ date_column_name }}) >= TIMESTAMP('{{ var("batch_start_date") }}')
        {% endif %}
        and TIMESTAMP({{ date_column_name }}) < TIMESTAMP('{{ var("batch_end_date") }}')

    {% endif %}

{% endtest %}
