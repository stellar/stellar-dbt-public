{% test incremental_unique(model, column_name, date_column_name, greater_than_equal_to, condition) %}

    {{ config(severity = 'error') }}
    {% set condition = condition | default('') %}
    {% set date_column_name = date_column_name | default('closed_at') %}
    {% set greater_than_equal_to = greater_than_equal_to | default('') %}

    {% if flags.FULL_REFRESH %}
        -- Full refresh mode: no date filter
      select
          {{ column_name }} as unique_field
      from {{ model }}
      where true
      and {{ column_name }} is not null

      {% if condition != '' %}
      and {{ condition }}
      {% endif %}

      qualify row_number() over (partition by {{ column_name }}) > 1

      {% else %}
        -- Incremental mode: filter to batch window [batch_start_date, batch_end_date)
      select
          {{ column_name }} as unique_field
      from {{ model }}
      where true
      and {{ column_name }} is not null
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

      qualify row_number() over (partition by {{ column_name }}) > 1
    {% endif %}
{% endtest %}
