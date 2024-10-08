/*
Macro: apply_recovery_filters

Description:
This macro generates the appropriate date filters for various recovery scenarios.
It covers single-day recovery, date range recovery, and full recovery modes.
The macro also handles the scenario where recovery is not required, ensuring no data is processed unnecessarily.

Parameters:
- `table_alias` (str): The alias of the table in the query.
- `date_column` (str): The name of the date column to filter on. Defaults to 'closed_at'.

Usage:
{% set recovery_filter = apply_recovery_filters('table_alias', 'date_column') %}
WHERE {{ recovery_filter }}

Returns:
A SQL condition string for filtering data based on the recovery mode.

Notes:
This macro relies on the following variables being set:
- recovery: Indicates if recovery mode is enabled (true or false).
- recovery_type: Specifies the recovery mode ('SingleDay', 'Range', 'Full').
- recovery_date: The specific date to recover (for 'SingleDay' recovery).
- recovery_start_day and recovery_end_day: The date range for recovery (for 'Range' recovery).
- execution_date: The current execution date (for 'Full' recovery).
*/

{% macro apply_recovery_filters(table_alias, date_column='closed_at', execution_date=CURRENT_TIMESTAMP()) %}
    {% if var('recovery', false) %}
        {% if var('recovery_type') == 'SingleDay' %}
            -- Single day recovery: Process data for a specific date defined by 'recovery_date'.
            cast({{ table_alias }}.{{ date_column }} as date) = DATE('{{ var("recovery_date") }}')
        {% elif var('recovery_type') == 'Range' %}
            -- Date range recovery: Process data for a date range specified by 'recovery_start_day' and 'recovery_end_day'.
            cast({{ table_alias }}.{{ date_column }} as date) BETWEEN DATE('{{ var("recovery_start_day") }}') AND DATE('{{ var("recovery_end_day") }}')
        {% elif var('recovery_type') == 'Full' %}
            -- Full recovery: Process all historical data up to the day before the current execution date.
            {{ table_alias }}.{{ date_column }} < timestamp_trunc('{{ execution_date }}', day)
        {% else %}
            -- Invalid recovery type specified: No records will be processed.
            FALSE
        {% endif %}
    {% else %}
        -- Not in recovery mode: No recovery filters will be applied.
        FALSE
    {% endif %}
{% endmacro %}
