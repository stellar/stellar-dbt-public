{% macro calculate_snapshot_diff_for_day_range(
    source_name,
    target_name,
    temp_source_table,
    temp_target_table,
    snapshot_start_date,
    snapshot_end_date,
    updated_at_col_name,
    valid_from_col_name,
    valid_to_col_name,
    source_unique_key,
    partition_by_key,
    cluster_by_key
) -%}

{#
-- Calculate the snapshot diff for [snapshot_start_date, snapshot_end_date) in a single
-- set-based pass instead of looping over every day in the range.
--
-- SCD Type-2 semantics are unchanged from the day-by-day implementation:
--   * one version per entity per day -- the last source row of that day wins
--   * valid_to is always the valid_from of that entity's next version
--
-- The second rule means valid_to is exactly LEAD(valid_from) over an entity's ordered
-- versions, so the whole range chains with one window function. No day in the range
-- depends on the previous day's output, so no iteration is needed.
--
-- The only value the source cannot supply is each entity's version that was already open
-- when the range started. That row is read from the target once, positionally: the
-- entity's latest version with valid_from before snapshot_start_date. The day-by-day
-- implementation instead selected valid_to IS NULL, which returns the state as of *now*
-- rather than as of snapshot_start_date, and is why re-running a historical range could
-- not reproduce it.
--
-- Two statements are emitted:
--   1. temp_source_table -- one row per entity per day in the range, with valid_from set.
--   2. temp_target_table -- the rows above plus, for each entity that changed inside the
--      range, its previously open version re-closed against the range's first new
--      version. valid_to is chained across both sets at once. This is the diff the
--      materialization merges into the target on (source_unique_key, valid_from).
--
-- Entities with no source activity in the range contribute nothing to the diff.
--
-- Known limitation carried over from the day-by-day implementation: the diff only
-- inserts and updates, so a target row whose source row has since disappeared is not
-- removed. Repairing that requires the rollback step tracked separately.
#}

{%- set source_relation = ref(source_name) -%}

{%- if source_unique_key is sequence and source_unique_key is not string -%}
    {%- set source_unique_key_cols = source_unique_key -%}
{%- else -%}
    {%- set source_unique_key_cols = [source_unique_key] -%}
{%- endif -%}

{#-- Dates arrive as bare yyyy-mm-dd strings; tolerate pre-quoted values --#}
{%- set start_date = snapshot_start_date | string | replace("'", "") | trim -%}
{%- set end_date = snapshot_end_date | string | replace("'", "") | trim -%}

{%- if start_date >= end_date -%}
    {%- do exceptions.raise_compiler_error(
        "snapshot_start_date (" ~ start_date ~ ") must be earlier than snapshot_end_date (" ~ end_date ~ ")"
    ) -%}
{%- endif -%}

{%- set range_start_date = "date('" ~ start_date ~ "')" -%}
{%- set range_end_date = "date('" ~ end_date ~ "')" -%}
{%- set range_start_ts = "timestamp(" ~ range_start_date ~ ")" -%}

{%- set full_refresh_mode = (should_full_refresh()) -%}
{%- set existing_relation = load_relation(this) -%}

{#--
-- There are open versions to re-close only when a target already exists and is not being
-- rebuilt. On a full refresh the source alone describes the entire snapshot.
--#}
{%- set has_open_versions = existing_relation is not none and not full_refresh_mode -%}

{#--
-- Payload columns come from the source; valid_from and valid_to are appended by this
-- macro, so drop them from the source list if the source already exposes them.
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
-- The target may have drifted from the source (on_schema_change: append_new_columns adds
-- columns to the target over time, and a new source column is not added until the
-- materialization processes schema changes, which happens after this presql runs). Align
-- the open-version rows to the source column list so they can be unioned with the new
-- versions.
--#}
{%- if has_open_versions -%}
    {%- set target_col_names = adapter.get_columns_in_relation(existing_relation)
        | map(attribute="name") | map("lower") | list -%}
{%- endif -%}

{#-- Statement 1: one version per entity per day in the range --#}
{%- set new_versions_sql %}
    with source_ranked as (
        select
            {{ source_cols_csv }}
            , row_number() over (
                partition by {{ unique_key_csv }}, date({{ updated_at_col_name }})
                order by {{ updated_at_col_name }} desc
            ) as row_num
        from {{ source_relation }}
        where date({{ updated_at_col_name }}) >= {{ range_start_date }}
            and date({{ updated_at_col_name }}) < {{ range_end_date }}
    )

    select
        {{ source_cols_csv }}
        , cast({{ updated_at_col_name }} as timestamp) as {{ valid_from_col_name }}
    from source_ranked
    where row_num = 1
{%- endset %}

{{ stellar_dbt_public.create_temp_table_with_data(temp_source_table, new_versions_sql, none, none) }}

{#--
-- Statement 2: chain the new versions together with the versions already open at
-- snapshot_start_date.
--
-- The open versions sort before every new version for their entity (valid_from below
-- range_start_ts, which every new valid_from is at or above), so LEAD closes each open
-- version against its entity's first new version and leaves the new versions' own
-- chaining untouched. An open version that receives no valid_to belongs to an entity
-- with no activity in the range and is dropped -- it is already correct in the target.
--
-- partition by is used rather than a join because the unique key may contain nulls
-- (a trustline has either liquidity_pool_id or asset_code/asset_issuer set, never both),
-- and partition by treats nulls as equal while = does not.
--#}
{%- set snapshot_diff_sql %}
    with new_versions as (
        select
            {{ source_cols_csv }}
            , {{ valid_from_col_name }}
            , false as is_open_version
        from {{ temp_source_table }}
    )

    {% if has_open_versions -%}
    , open_version_candidates as (
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
        {# valid_from carries the correctness; valid_to is redundant but prunes the valid_to-partitioned target #}
        where target_table.{{ valid_from_col_name }} < {{ range_start_ts }}
            and (
                target_table.{{ valid_to_col_name }} is null
                or target_table.{{ valid_to_col_name }} >= {{ range_start_ts }}
            )
    )

    , open_versions as (
        select
            {{ source_cols_csv }}
            , {{ valid_from_col_name }}
            , true as is_open_version
        from open_version_candidates
        where row_num = 1
    )
    {%- endif %}

    , all_versions as (
        select * from new_versions
        {%- if has_open_versions %}
        union all
        select * from open_versions
        {%- endif %}
    )

    , chained_versions as (
        select
            {{ source_cols_csv }}
            , {{ valid_from_col_name }}
            , is_open_version
            , lead({{ valid_from_col_name }}) over (
                partition by {{ unique_key_csv }}
                order by {{ valid_from_col_name }}
            ) as {{ valid_to_col_name }}
        from all_versions
    )

    select
        {{ source_cols_csv }}
        , {{ valid_from_col_name }}
        , {{ valid_to_col_name }}
    from chained_versions
    where not (is_open_version and {{ valid_to_col_name }} is null)
{%- endset %}

{{ stellar_dbt_public.create_temp_table_with_data(temp_target_table, snapshot_diff_sql, partition_by_key, cluster_by_key) }}

{%- endmacro %}
