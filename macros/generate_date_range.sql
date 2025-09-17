{% macro generate_date_range(start_date, end_date) %}
    {% set date_range_daily = dates_in_range(
        start_date,
        end_date,
        in_fmt="%Y-%m-%d",
        out_fmt="'%Y-%m-%d'",
    ) %}
    {{ return(date_range_daily) }}
{% endmacro %}
