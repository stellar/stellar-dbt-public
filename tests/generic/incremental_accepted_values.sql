{% test incremental_accepted_values(model, column_name, date_column_name, greater_than_equal_to, condition, quote, values=[]) %}

    {{ config(severity = 'error') }}
    {% set condition = condition | default('') %}
    {% set date_column_name = date_column_name | default('closed_at') %}
    {% set greater_than_equal_to = greater_than_equal_to | default('') %}
    {% set quote = quote | default(false) %}
    {% set values_string = [] %}
    {% for value in values %}
        {% do values_string.append("'" + value|string + "'") %}
    {% endfor %}
    {% set values_string = values_string | join(', ') %}
    {% set values = values | join(', ') %}

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

        group by {{ column_name }}

    )

    select value_field
    from all_values
    where value_field not in (
        {% if quote %}
            {{ values_string }}
        {% else %}
            {{ values }}
        {% endif %}
    )

{% endtest %}
