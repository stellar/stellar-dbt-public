{% test incremental_unique(model, column_name, date_column_name, greater_than_equal_to, less_than_equal_to, condition) %}

    {{ config(severity = 'error') }}
    {% set condition = condition | default('') %}
    {% set date_column_name = date_column_name | default('closed_at') %}
    {% set greater_than_equal_to = greater_than_equal_to | default('2 day') %}
    {% set less_than_equal_to = less_than_equal_to | default('') %}

    {% if flags.FULL_REFRESH %}
        -- Full refresh mode: no date filter, just check for null values
      with dbt_test__target as (

        select {{ column_name }} as unique_field
        from {{ model }}
        where true
        and {{ column_name }} is not null

        {% if condition != '' %}
        and {{ condition }}
        {% endif %}

      )

      select
          unique_field,
          count(*) as n_records

      from dbt_test__target
      group by unique_field
      having count(*) > 1

      {% else %}
        -- Incremental mode: filter records based on greater_than_equal_to
      with dbt_test__target as (

        select {{ column_name }} as unique_field
        from {{ model }}
        where true
        and {{ column_name }} is not null
        and TIMESTAMP({{ date_column_name }}) >= TIMESTAMP_SUB('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL {{ greater_than_equal_to }} )

        {% if less_than_equal_to != '' %}
        and TIMESTAMP({{ date_column_name }}) <= TIMESTAMP_ADD('{{ dbt_airflow_macros.ts(timezone=none) }}', INTERVAL {{ less_than_equal_to }} )
        {% endif %}

        {% if condition != '' %}
        and {{ condition }}
        {% endif %}
      )

      select
          unique_field,
          count(*) as n_records

      from dbt_test__target
      group by unique_field
      having count(*) > 1
    {% endif %}
{% endtest %}
