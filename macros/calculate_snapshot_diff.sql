{% macro calculate_snapshot_diff(
    source_name,
    target_name,
    temp_source_table,
    temp_target_table,
    chunk_start_date,
    chunk_end_date,
    updated_at_col_name,
    valid_from_col_name,
    valid_to_col_name,
    source_unique_key,
    partition_by_key,
    cluster_by_key,
    key_filter,
    read_boundary_from_target
) -%}

{#
-- Build the diff for one chunk of a snapshot rebuild, as SQL for the caller to execute.
--
-- SCD Type-2 valid_to is always the valid_from of the entity's next version, which makes it
-- LEAD(valid_from) over the entity's ordered versions. So a chunk of any length is one
-- window function over its versions; there is no per-day iteration.
--
-- Everything the chunk needs beyond its own source rows is a single version per entity: the
-- one that was current when the chunk began. The caller guarantees the target holds nothing
-- starting at or after chunk_start_date -- snapshot_reset_from_start deleted it, and earlier
-- chunks only ever wrote versions before their own end -- so that version is simply the
-- entity's latest, and boundary versions and source versions can never collide on valid_from.
--
-- Only entities the source changed inside the chunk take part. An entity with no source rows
-- in the chunk contributes nothing to the diff and is left exactly as it is, which is what
-- keeps a chunk's cost proportional to what actually changed rather than to the table.
--
-- Two statements are emitted:
--   1. temp_source_table -- one version per entity per day in the chunk, with valid_from set.
--   2. temp_target_table -- those versions plus each entity's boundary version, chained. This
--      is the diff the caller merges into the target on (source_unique_key, valid_from).
--
-- partition by is used throughout rather than joins so entities are grouped correctly even
-- when a key column is null.
#}

{%- set source_relation = ref(source_name) -%}

{%- if source_unique_key is sequence and source_unique_key is not string -%}
    {%- set source_unique_key_cols = source_unique_key -%}
{%- else -%}
    {%- set source_unique_key_cols = [source_unique_key] -%}
{%- endif -%}

{#-- Dates arrive as bare yyyy-mm-dd strings; tolerate pre-quoted values --#}
{%- set start_date = chunk_start_date | string | replace("'", "") | trim -%}
{%- set end_date = chunk_end_date | string | replace("'", "") | trim -%}

{%- set chunk_start = "date('" ~ start_date ~ "')" -%}
{%- set chunk_end = "date('" ~ end_date ~ "')" -%}
{%- set chunk_start_ts = "timestamp(" ~ chunk_start ~ ")" -%}

{#--
-- Payload columns come from the source; valid_from and valid_to are appended here, so drop
-- them from the source list if the source already exposes them.
--#}
{%- set reserved_col_names = [valid_from_col_name | lower, valid_to_col_name | lower] -%}
{%- set source_columns = [] -%}
{%- for column in adapter.get_columns_in_relation(source_relation) -%}
    {%- if column.name | lower not in reserved_col_names -%}
        {%- do source_columns.append(column) -%}
    {%- endif -%}
{%- endfor -%}
{%- set source_cols_csv = get_quoted_csv(source_columns | map(attribute="name")) -%}
{%- set unique_key_csv = get_quoted_csv(source_unique_key_cols) -%}

{#--
-- The target may have drifted from the source: on_schema_change adds columns to the target
-- over time, and a new source column is not added to the target until the caller processes
-- schema changes, which happens after this SQL is built. Align the boundary rows to the
-- source column list so they can be unioned with the source versions.
--#}
{#--
-- Introspect the target directly rather than via load_relation(this). dbt's relation cache
-- is built at the start of the run, and the chunk that creates the table does so with a raw
-- CTAS inside a statement() block, which the cache never learns about -- so on a first run
-- load_relation would still report the table as missing for every chunk after the first.
--#}
{%- if read_boundary_from_target -%}
    {%- set target_columns = adapter.get_columns_in_relation(target_name) -%}
    {%- if target_columns | length == 0 -%}
        {%- do exceptions.raise_compiler_error(
            "Cannot read boundary versions: " ~ target_name ~ " reported no columns. Treating that "
            ~ "as an empty column list would null out every boundary payload instead of failing."
        ) -%}
    {%- endif -%}
    {%- set target_col_names = target_columns | map(attribute="name") | map("lower") | list -%}
{%- endif -%}

{#-- Statement 1: one version per entity per day in the chunk --#}
{%- set source_versions_sql %}
    with source_ranked as (
        select
            {{ source_cols_csv }}
            , row_number() over (
                partition by {{ unique_key_csv }}, date({{ updated_at_col_name }})
                order by {{ updated_at_col_name }} desc
            ) as row_num
        from {{ source_relation }}
        where date({{ updated_at_col_name }}) >= {{ chunk_start }}
            and date({{ updated_at_col_name }}) < {{ chunk_end }}
            {{ key_filter }}
    )

    select
        {{ source_cols_csv }}
        , cast({{ updated_at_col_name }} as timestamp) as {{ valid_from_col_name }}
    from source_ranked
    where row_num = 1
{%- endset %}

{{ stellar_dbt_public.create_temp_table_with_data(temp_source_table, source_versions_sql, none, none) }}

{#-- Statement 2: chain the chunk's versions onto the version that was current when it began --#}
{%- set snapshot_diff_sql %}
    with source_versions as (
        select
            {{ source_cols_csv }}
            , {{ valid_from_col_name }}
            , 'source' as row_origin
        from {{ temp_source_table }}
    )

    {% if read_boundary_from_target -%}
    , boundary_candidates as (
        select
            {%- for column in source_columns %}
            {%- if column.name | lower in target_col_names %}
            {{ "," if not loop.first }} target_table.{{ adapter.quote(column.name) }}
            {%- else %}
            {{ "," if not loop.first }} cast(null as {{ column.data_type }}) as {{ adapter.quote(column.name) }}
            {%- endif %}
            {%- endfor %}
            , target_table.{{ valid_from_col_name }}
            , row_number() over (
                partition by
                    {%- for key in source_unique_key_cols %}
                    {{ "," if not loop.first }} target_table.{{ adapter.quote(key) }}
                    {%- endfor %}
                order by target_table.{{ valid_from_col_name }} desc
            ) as row_num
        from {{ target_name }} as target_table
        {# a version current at the chunk start is open or closed no earlier; this prunes a target partitioned by valid_to #}
        where target_table.{{ valid_from_col_name }} < {{ chunk_start_ts }}
            and (
                target_table.{{ valid_to_col_name }} is null
                or target_table.{{ valid_to_col_name }} >= {{ chunk_start_ts }}
            )
            {{ stellar_dbt_public.snapshot_key_filter(source_unique_key_cols, 'target_table') }}
    )

    , boundary_versions as (
        select
            {{ source_cols_csv }}
            , {{ valid_from_col_name }}
            , 'boundary' as row_origin
        from boundary_candidates
        where row_num = 1
    )
    {%- endif %}

    , all_versions as (
        select * from source_versions
        {%- if read_boundary_from_target %}
        union all
        select * from boundary_versions
        {%- endif %}
    )

    , flagged_versions as (
        select
            {{ source_cols_csv }}
            , {{ valid_from_col_name }}
            , countif(row_origin = 'source') over (
                partition by {{ unique_key_csv }}
            ) as source_versions_for_entity
        from all_versions
    )

    select
        {{ source_cols_csv }}
        , {{ valid_from_col_name }}
        , lead({{ valid_from_col_name }}) over (
            partition by {{ unique_key_csv }}
            order by {{ valid_from_col_name }}
        ) as {{ valid_to_col_name }}
    from flagged_versions where source_versions_for_entity > 0

{%- endset %}

{{ stellar_dbt_public.create_temp_table_with_data(temp_target_table, snapshot_diff_sql, partition_by_key, cluster_by_key) }}

{%- endmacro %}
