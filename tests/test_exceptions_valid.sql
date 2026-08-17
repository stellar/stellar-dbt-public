-- Guards seeds/public_test_exceptions.csv against rows that cannot do what their
-- author intended: a target no test registers, an entity_column the target does not
-- expose, a day scope on a target that has no day column, a half-filled scope, a
-- missing reason/owner, or an expiry that contradicts the exception_kind. A silently
-- inert exception row is the main failure mode of a table like this -- the alert
-- keeps firing while the row looks like it should have stopped it, and nobody
-- re-reads a row they believe works.
--
-- Structural checks only. An *expired* temporary row needs no alert of its own: the
-- exception stops applying and the underlying test starts failing again on its next
-- run, which is exactly the review prompt we want.
--
-- The registry it validates against is test_exception_targets()
-- (macros/test_exceptions.sql), so wiring a new test cannot drift from the rows
-- allowed to target it.

{{ config(
    severity="error"
    , tags=["singular_test"]
    , enabled=var("is_singular_airflow_task") == "true"
    )
}}

{%- set registry = test_exception_targets() -%}
{%- set target_structs = [] -%}
{%- set column_structs = [] -%}
{%- for target_key, spec in registry.items() -%}
    {%- do target_structs.append(
        "struct('" ~ target_key ~ "' as target_key, "
        ~ (spec['allows_day_scope'] | string | lower) ~ " as allows_day_scope)"
    ) -%}
    {%- for entity_column in spec['entity_columns'] -%}
        {%- do column_structs.append(
            "struct('" ~ target_key ~ "' as target_key, '" ~ entity_column ~ "' as entity_column)"
        ) -%}
    {%- endfor -%}
{%- endfor -%}

-- Registered targets and their scopable columns come from test_exception_targets()
-- as two lists, not one: a target with no entity columns still has to be
-- registered, or its rows would look unregistered rather than unscopable.
with registered_targets as (
    select
        target.target_key
        , target.allows_day_scope
    from unnest([
        {{ target_structs | join('\n        , ') }}
    ]) as target
)

, registered_columns as (
    select
        entity.target_key
        , array_agg(entity.entity_column) as entity_columns
    from unnest([
        {{ column_structs | join('\n        , ') }}
    ]) as entity
    group by entity.target_key
)

, exceptions_with_registry as (
    select
        ex.target_kind
        , ex.exception_kind
        , ex.target_key
        , ex.entity_column
        , ex.entity_key
        , ex.day_from
        , ex.day_to
        , ex.expires_on
        , ex.reason
        , ex.owner
        , rt.target_key is not null as is_registered
        , coalesce(rc.entity_columns, array<string>[]) as entity_columns
        , coalesce(rt.allows_day_scope, false) as allows_day_scope
    from {{ ref('public_test_exceptions') }} as ex
    left join registered_targets as rt
        on nullif(trim(ex.target_key), '') = rt.target_key
    left join registered_columns as rc
        on nullif(trim(ex.target_key), '') = rc.target_key
)

, validated as (
    select
        ewr.target_kind
        , ewr.exception_kind
        , ewr.target_key
        , ewr.entity_column
        , ewr.entity_key
        , ewr.expires_on
        , ewr.owner
        , case
            when coalesce(nullif(trim(ewr.target_kind), ''), '') != 'singular'
                then 'unsupported_target_kind: only singular tests can be wired'
            when coalesce(nullif(trim(ewr.exception_kind), ''), '') not in ('temporary', 'structural')
                then 'unknown_exception_kind: must be temporary or structural'
            when nullif(trim(ewr.reason), '') is null then 'missing_reason'
            when nullif(trim(ewr.owner), '') is null then 'missing_owner'
            when nullif(trim(ewr.exception_kind), '') = 'temporary' and ewr.expires_on is null
                then 'missing_expires_on: temporary exceptions must expire'
            when nullif(trim(ewr.exception_kind), '') = 'structural' and ewr.expires_on is not null
                then 'structural_with_expires_on: a permanent carve-out must not expire'
            when not ewr.is_registered
                then 'unregistered_target_key: not in test_exception_targets()'
            when nullif(trim(ewr.entity_key), '') is null and nullif(trim(ewr.entity_column), '') is not null
                then 'entity_column_without_entity_key'
            when
                nullif(trim(ewr.entity_key), '') is not null
                and coalesce(nullif(trim(ewr.entity_column), ''), '') not in unnest(ewr.entity_columns)
                then 'unknown_entity_column: target does not expose it'
            when (ewr.day_from is not null or ewr.day_to is not null) and not ewr.allows_day_scope
                then 'day_scope_not_supported: target has no data day'
            when ewr.day_from is not null and ewr.day_to is not null and ewr.day_from > ewr.day_to
                then 'day_range_inverted'
        end as validation_error
    from exceptions_with_registry as ewr
)

select
    validated.target_kind
    , validated.exception_kind
    , validated.target_key
    , validated.entity_column
    , validated.entity_key
    , validated.expires_on
    , validated.owner
    , validated.validation_error
from validated
where validated.validation_error is not null
