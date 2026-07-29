{# Returns the `batch_size` for a microbatch incremental model.

   Resolution order, first match wins:

   1. `DBT_MICROBATCH_BATCH_SIZE`, when set and non-empty. Airflow sets this to
      override the batch granularity for a single run, mostly for partial
      backfills: a window of a few days should not be walked in the same
      granularity a full rebuild uses, and vice versa. It is passed as an env
      var rather than `--vars` because the backfill build wraps the dbt command
      in a bash retry loop that is not compatible with `--vars`.

   2. `year` on a full refresh. Rebuilding all of history in day-sized batches
      is thousands of BigQuery jobs; year-sized batches keep a full rebuild to
      a tractable number.

   3. `day` otherwise, matching the scheduled run cadence.

   `batch_size` must be **at least as coarse** as the model's
   `partition_by.granularity` -- a finer batch would overwrite a whole
   partition with a fraction of its rows, which `bq_validate_microbatch_config`
   rejects. Every model using the defaults below is day-partitioned. A model
   partitioned coarser than `day` must pass its own `default`, e.g.
   `microbatch_batch_size(default='month')`.

   Note on `flags.FULL_REFRESH`: dbt discourages using flags as an input to
   parse-time configuration, because a cached partial parse can carry a stale
   value into a later invocation
   (https://docs.getdbt.com/reference/dbt-jinja-functions/flags). `batch_size`
   is parse-time config, so that caveat applies here. It is accepted because
   the alternative -- requiring every caller to set the env var -- means a
   forgotten variable silently rebuilds all of history in day batches. Airflow
   runs dbt in a fresh pod with no prior `partial_parse.msgpack`, so the stale
   case is a local-development concern: if a local `--full-refresh` run is
   followed by a normal run, use `--no-partial-parse` or clear `target/`.

   Usage:
       {% set batch_size = microbatch_batch_size() %}
       {% set meta_config = { "batch_size": batch_size, ... } %}
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
