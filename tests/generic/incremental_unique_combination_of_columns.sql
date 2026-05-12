{% test incremental_unique_combination_of_columns(model, date_column_name, greater_than_equal_to, condition, combination_of_columns=[]) %}

    {# Convert columns list into a comma-separated string for SQL #}

    {{ config(severity = 'error') }}
    {% set condition = condition | default('') %}
    {% set date_column_name = date_column_name | default('closed_at') %}
    {% set greater_than_equal_to = greater_than_equal_to | default('') %}
    {% set columns_list = combination_of_columns | join(', ') %}

    select
        {{ columns_list }}
    from {{ model }}
    {% if flags.FULL_REFRESH %}
        -- Full refresh mode: no date filter
        {% if condition != '' %}
        where {{ condition }}
        {% endif %}
    {% else %}
        -- Incremental mode: filter to batch window [batch_start_date, batch_end_date)
        where true
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
    qualify row_number() over (partition by {{ columns_list }}) > 1

{% endtest %}
