{% test incremental_not_empty(model, column_name, date_column_name, greater_than_equal_to, condition) %}

    {#
        Fails on an empty string as well as a NULL.

        incremental_not_null passes on '', which is how a column can go empty
        across an entire protocol upgrade without a single test turning red.
        That is what happened to history_ledgers.node_id under CAP-88: the XDR
        accessor matched the union arm by name, stopped matching, and wrote ''
        with no error anywhere in the pipeline.

        Use `condition` to exclude rows where empty is the correct answer,
        rather than lowering the severity. A test that is expected to fail is
        a test that gets disabled.
    #}

    {{ config(severity = 'error') }}
    {% set date_column_name = date_column_name | default('closed_at') %}
    {% set greater_than_equal_to = greater_than_equal_to | default('') %}
    {% set condition = condition | default('') %}

    {% if flags.FULL_REFRESH %}
        -- Full refresh mode: no date filter, check the whole table
        select {{ column_name }}
        from {{ model }}
        where true
        and coalesce({{ column_name }}, '') = ''

        {% if condition != '' %}
        and {{ condition }}
        {% endif %}

    {% else %}
        -- Incremental mode: filter to batch window [batch_start_date, batch_end_date)
        select {{ column_name }}
        from {{ model }}
        where true
        and coalesce({{ column_name }}, '') = ''
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
