{% macro bq_validate_microbatch_config(config) %}
{#
    Root-project override of the dbt-bigquery built-in validation.
    See https://github.com/dbt-labs/dbt-core/issues/11278

    The built-in requires `partition_by.granularity` to exactly match
    `batch_size`, which blocks running coarser batches (e.g. month-sized
    batches over a day-partitioned table) for backfills. Microbatch on
    bigquery compiles to a *dynamic* insert_overwrite, which replaces exactly
    the set of partitions present in each batch's output, so a batch spanning
    multiple partitions is safe.

    A batch_size FINER than the partition granularity is still an error:
    each batch would overwrite a whole partition with only a fraction of
    its rows.
#}
    {% if config.get('partition_by') is none %}
        {% set missing_partition_msg -%}
            The 'microbatch' strategy requires a `partition_by` config.
        {%- endset %}
        {% do exceptions.raise_compiler_error(missing_partition_msg) %}
    {% endif %}

    {% set granularities = ['hour', 'day', 'month', 'year'] %}
    {% set partition_granularity = config.get('partition_by').granularity | default('day', true) %}
    {% set batch_size = config.get('batch_size') %}

    {% if partition_granularity not in granularities
        or batch_size not in granularities
        or granularities.index(batch_size) < granularities.index(partition_granularity) %}
        {% set invalid_granularity_msg -%}
            The 'microbatch' strategy requires `batch_size` to be at least as coarse as the `partition_by` granularity.
            Got:
              `batch_size`: {{ batch_size }}
              `partition_by.granularity`: {{ partition_granularity }}
        {%- endset %}
        {% do exceptions.raise_compiler_error(invalid_granularity_msg) %}
    {% endif %}
{% endmacro %}
