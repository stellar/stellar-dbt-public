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
-- What the source cannot supply is the versions the target already holds: each entity's
-- version starting before the range (whose valid_to the range may change) and any
-- versions inside the range that the source no longer produces. Those are read from the
-- target and chained together with the source versions, so the rebuilt chain is gapless
-- and non-overlapping whichever set a row came from.
--
-- The day-by-day implementation instead seeded from valid_to IS NULL, which is the state
-- as of *now* rather than as of snapshot_start_date, and is why re-running a historical
-- range could not reproduce it.
--
-- Two statements are emitted:
--   1. temp_source_table -- one row per entity per day in the range, with valid_from set.
--   2. temp_target_table -- for every entity the source changed inside the range, its
--      rebuilt chain from the version before the range forward. This is the diff the
--      materialization merges into the target on (source_unique_key, valid_from).
--
-- Entities with no source activity in the range contribute nothing to the diff.
--
-- Known limitation carried over from the day-by-day implementation: the diff only
-- inserts and updates, so a target version whose source row has since disappeared is not
-- removed -- it stays in the chain, correctly linked, rather than being dropped.
-- Removing it requires the rollback step tracked separately.
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
-- Statement 2: rebuild the version chain for every entity the source changed inside the
-- range.
--
-- Three sets of versions take part:
--   * source versions -- statement 1, every version the source implies inside the range.
--   * the pre-range version -- each entity's latest version starting before the range.
--     Its valid_to has to be recomputed because the range may open a new version in
--     front of it.
--   * in-range target versions -- versions the target already holds inside the range.
--     They are needed because an entity's chain cannot be rebuilt from the source alone
--     when the target holds versions the source no longer produces, and because a target
--     version may sit between two source versions.
--
-- A source version always supersedes the target version at the same valid_from, so the
-- target copy is dropped and the source payload wins. Everything that survives is then
-- chained with one LEAD, which is what makes valid_to gapless and non-overlapping no
-- matter which of the three sets a row came from.
--
-- Only entities with source activity in the range are touched at all. An entity the
-- source did not change contributes nothing to the diff and is left exactly as it is.
--
-- partition by is used throughout rather than joins because the unique key may contain
-- nulls (a trustline has either liquidity_pool_id or asset_code/asset_issuer set, never
-- both), and partition by treats nulls as equal while = does not.
--#}
{%- set snapshot_diff_sql %}
    with source_versions as (
        select
            {{ source_cols_csv }}
            , {{ valid_from_col_name }}
            , 'source' as row_origin
        from {{ temp_source_table }}
    )

    {% if has_open_versions -%}
    , target_candidates as (
        select
            {%- for column in source_columns %}
            {%- if column.name | lower in target_col_names %}
            {{ "," if not loop.first }} target_table.{{ adapter.quote(column.name) }}
            {%- else %}
            {{ "," if not loop.first }} cast(null as {{ column.data_type }}) as {{ adapter.quote(column.name) }}
            {%- endif %}
            {%- endfor %}
            , target_table.{{ valid_from_col_name }}
            , max(
                case
                    when target_table.{{ valid_from_col_name }} < {{ range_start_ts }}
                        then target_table.{{ valid_from_col_name }}
                end
            ) over (
                partition by
                    {%- for key in source_unique_key_cols %}
                    {{ "," if not loop.first }} target_table.{{ adapter.quote(key) }}
                    {%- endfor %}
            ) as latest_valid_from_before_range
        from {{ target_name }} as target_table
        {# a version still open at the range start has valid_to null or at/after it; this prunes the valid_to-partitioned target #}
        where target_table.{{ valid_to_col_name }} is null
            or target_table.{{ valid_to_col_name }} >= {{ range_start_ts }}
    )

    , target_versions as (
        select
            {{ source_cols_csv }}
            , {{ valid_from_col_name }}
            , case
                when {{ valid_from_col_name }} >= {{ range_start_ts }} then 'target_in_range'
                else 'target_before_range'
            end as row_origin
        from target_candidates
        where {{ valid_from_col_name }} >= {{ range_start_ts }}
            or {{ valid_from_col_name }} = latest_valid_from_before_range
    )
    {%- endif %}

    , all_versions as (
        select * from source_versions
        {%- if has_open_versions %}
        union all
        select * from target_versions
        {%- endif %}
    )

    , flagged_versions as (
        select
            {{ source_cols_csv }}
            , {{ valid_from_col_name }}
            , row_origin
            , countif(row_origin = 'source') over (
                partition by {{ unique_key_csv }}
            ) as source_versions_for_entity
            , countif(row_origin = 'source') over (
                partition by {{ unique_key_csv }}, {{ valid_from_col_name }}
            ) as source_versions_at_valid_from
        from all_versions
    )

    , versions_to_chain as (
        select
            {{ source_cols_csv }}
            , {{ valid_from_col_name }}
        from flagged_versions
        {#-- leave entities the source did not change inside the range untouched --#}
        where source_versions_for_entity > 0
            {#-- the source payload wins over the target copy of the same version --#}
            and not (row_origin = 'target_in_range' and source_versions_at_valid_from > 0)
    )

    select
        {{ source_cols_csv }}
        , {{ valid_from_col_name }}
        , lead({{ valid_from_col_name }}) over (
            partition by {{ unique_key_csv }}
            order by {{ valid_from_col_name }}
        ) as {{ valid_to_col_name }}
    from versions_to_chain
{%- endset %}

{{ stellar_dbt_public.create_temp_table_with_data(temp_target_table, snapshot_diff_sql, partition_by_key, cluster_by_key) }}

{%- endmacro %}
