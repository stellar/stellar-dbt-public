{% test recency(model, field, datepart, interval, ignore_time_component=False, group_by_columns = [], timestamp_val=none) %}

-- ported from https://github.com/dbt-labs/dbt-utils/blob/main/macros/generic_tests/recency.sql

{{ config(severity = 'error') }}

{% if timestamp_val %}
    {% set threshold = 'cast(' ~ dbt.dateadd(datepart, interval * -1, "cast('" ~ timestamp_val ~ "' as timestamp)") ~ ' as ' ~ ('date' if ignore_time_component else dbt.type_timestamp()) ~ ')' %}
{% else %}
    {% set threshold = 'cast(' ~ dbt.dateadd(datepart, interval * -1, dbt.current_timestamp()) ~ ' as ' ~ ('date' if ignore_time_component else dbt.type_timestamp()) ~ ')' %}
{% endif %}

{% if group_by_columns|length() > 0 %}
  {% set select_gb_cols = group_by_columns|join(' ,') + ', ' %}
  {% set groupby_gb_cols = 'group by ' + group_by_columns|join(',') %}
{% endif %}


with recency as (

    select

      {{ select_gb_cols }}
      {% if ignore_time_component %}
        cast(max({{ field }}) as date) as most_recent
      {%- else %}
        max({{ field }}) as most_recent
      {%- endif %}

    from {{ model }}

    {{ groupby_gb_cols }}

)

select

    {{ select_gb_cols }}
    most_recent,
    {{ threshold }} as threshold

from recency
where most_recent < {{ threshold }}
   or most_recent is null

{% endtest %}
