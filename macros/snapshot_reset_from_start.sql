{% macro snapshot_reset_from_start(
    target_name,
    start_date,
    valid_from_col_name,
    valid_to_col_name,
    key_filter
) -%}

{#
-- Return the target to the state it held at start_date, so the rebuild that follows is
-- reproducible: every run of a given start_date begins from the same place, whatever was
-- there before.
--
-- Two statements, and the order is load bearing:
--
--   1. Delete every version starting at or after start_date. The rebuild recreates the ones
--      the source still produces; anything else was never real and does not come back.
--   2. Reopen the versions that were closed by a deleted successor. After statement 1 every
--      surviving version starts before start_date, so at most one version per entity can
--      still carry a valid_to at or after start_date -- the one that was current at
--      start_date. Reopening first would instead open every version after start_date and
--      leave an entity with several open rows.
--
-- Neither statement touches a version already closed before start_date, and statement 2
-- leaves an already open version alone, because `null >= start_date` is null rather than
-- true.
--
-- valid_from carries the correctness of statement 1. The extra valid_to predicate is implied
-- by it -- a version starting at or after start_date is either open or closed later still --
-- and is there so the delete can prune a target partitioned by valid_to.
#}

{%- set start_timestamp = "timestamp(date('" ~ start_date ~ "'))" -%}

    delete from {{ target_name }}
    where {{ valid_from_col_name }} >= {{ start_timestamp }}
        and (
            {{ valid_to_col_name }} is null
            or {{ valid_to_col_name }} >= {{ start_timestamp }}
        )
        {{ key_filter }};

    update {{ target_name }}
    set {{ valid_to_col_name }} = null
    where {{ valid_to_col_name }} >= {{ start_timestamp }}
        {{ key_filter }};

{%- endmacro %}
