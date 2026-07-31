{# Returns the `begin` date string for a microbatch incremental model.

   Non-ci targets get the default (typically the project's earliest data,
   e.g. '2015-09-30'). Under target=ci, return today - N days so slim-ci
   first-builds only walk a short window instead of every day from the
   project's epoch. N defaults to 30 and can be overridden by the
   `microbatch_ci_window_days` var so a CI run can widen the window via
   --vars without editing this macro.

   Uses `run_started_at` (a timezone-aware pendulum UTC datetime that is
   constant for the whole run) so every model in a run computes the same
   window and there is no drift across a UTC midnight boundary.

   Usage:
       {% set begin = microbatch_begin() %}
       {% set meta_config = { "begin": begin, ... } %}
#}
{% macro microbatch_begin(default='2015-09-30') %}
    {%- if target.name == 'ci' -%}
        {%- set window_days = var('microbatch_ci_window_days', 30) | int -%}
        {{ return((run_started_at - modules.datetime.timedelta(days=window_days)).strftime('%Y-%m-%d')) }}
    {%- else -%}
        {{ return(default) }}
    {%- endif -%}
{% endmacro %}
