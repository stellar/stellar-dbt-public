{# Returns the `batch_size` for a microbatch model.

   1. `DBT_MICROBATCH_BATCH_SIZE` if set -- Airflow's per-run override, mostly
      for partial backfills.
   2. `year` on a full refresh, so rebuilding all history is not thousands of
      day-sized batches.
   3. `day` otherwise, matching the scheduled cadence.

   `batch_size` must be at least as coarse as the model's
   `partition_by.granularity`, so a model partitioned coarser than `day` should
   pass its own `default`.

   Usage:
       {% set batch_size = microbatch_batch_size() %}
#}
{% macro microbatch_batch_size(default='day', full_refresh_default='year') %}
    {%- set override = env_var('DBT_MICROBATCH_BATCH_SIZE', '') -%}
    {%- if override -%}
        {{ return(override) }}
    {%- elif flags.FULL_REFRESH -%}
        {{ return(full_refresh_default) }}
    {%- else -%}
        {{ return(default) }}
    {%- endif -%}
{% endmacro %}
