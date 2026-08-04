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
-- Two statements:
--
--   1. Delete every version starting at or after start_date. The rebuild recreates the ones
--      the source still produces; anything else was never real and does not come back.
--   2. Reopen the version that was closed by a deleted successor, which is the one that was
--      current at start_date.
--
-- Deleting first is a cost choice, not a correctness one. Either order reaches the same
-- state, because the delete's predicate already covers every row the reopen would have
-- opened. But after the delete, statement 2 matches at most one version per entity -- run
-- the other way round it matches every version from start_date onwards, which on a large
-- snapshot is a far bigger update for the same result.
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
