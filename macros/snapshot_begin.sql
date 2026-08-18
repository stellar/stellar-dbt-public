{# Returns the `snapshot_default_start_date` for an SCD Type-2 snapshot model:
   the date a full refresh rebuilds the whole table from.

   Non-ci targets get the default, which is the model's genesis. Under
   target=ci, return today - N days so a full refresh walks one short window
   instead of chunking from that genesis (accounts and trustlines begin in
   2015, which is ~44 three-month chunks). N defaults to 30 and can be
   overridden by the `snapshot_ci_window_days` var, so a CI run can widen the
   window via --vars without editing this macro.

   Only the full-refresh path reads this. An ordinary run takes its start from
   the snapshot_start_date var and has no fallback, by design.

   Uses `run_started_at` (a timezone-aware pendulum UTC datetime that is
   constant for the whole run) so every model in a run computes the same
   window and there is no drift across a UTC midnight boundary.

   `default` is required: each snapshot's genesis is its own, and a shared
   fallback would quietly rebuild a model from the wrong date.

   Usage:
       {% set snapshot_default_start_date = snapshot_begin('2021-11-01') %}
       {% set meta_config = {
           "snapshot_default_start_date": snapshot_default_start_date, ... } %}
#}
{% macro snapshot_begin(default) %}
    {%- if not default -%}
        {%- do exceptions.raise_compiler_error(
            "snapshot_begin requires the model's genesis date, e.g. snapshot_begin('2021-11-01')"
        ) -%}
    {%- endif -%}
    {%- if target.name == 'ci' -%}
        {%- set window_days = var('snapshot_ci_window_days', 30) | int -%}
        {{ return((run_started_at - modules.datetime.timedelta(days=window_days)).strftime('%Y-%m-%d')) }}
    {%- else -%}
        {{ return(default) }}
    {%- endif -%}
{% endmacro %}
