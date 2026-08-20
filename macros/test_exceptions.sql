{#-
    Known-exception mechanism, shared with any project that installs this package
    -- see docs/test_exceptions.md for usage and the dbt/Jinja gotchas below.
-#}

{% macro exclude_test_exceptions(exceptions_relation, entity_columns={}, day_column=none) %}
    {#- Row-scoped `and not exists` predicate against exceptions_relation; see docs/test_exceptions.md. -#}
    {%- set target_key = model.name -%}
    {%- if execute -%}
        {#- config.get() only reflects this node's OWN config() once execute is true (dbt renders
            twice); the predicate below never depends on meta, so validation-only skips this early. -#}
        {%- set own_meta = config.get('meta', {}) -%}
        {%- if 'exception_scope' not in own_meta -%}
            {{ exceptions.raise_compiler_error(
                "exclude_test_exceptions: test '" ~ target_key ~ "' has no meta.exception_scope in its config()"
            ) }}
        {%- endif -%}
        {%- set scope = own_meta['exception_scope'] -%}
        {%- if entity_columns.keys() | list | sort != scope['entity_columns'] | list | sort -%}
            {{ exceptions.raise_compiler_error(
                "exclude_test_exceptions: '" ~ target_key ~ "' passed columns "
                ~ (entity_columns.keys() | list | sort | join(', '))
                ~ " but its own meta.exception_scope declares "
                ~ (scope['entity_columns'] | list | sort | join(', '))
            ) }}
        {%- endif -%}
        {%- if (day_column is not none) != scope['allows_day_scope'] -%}
            {{ exceptions.raise_compiler_error(
                "exclude_test_exceptions: '" ~ target_key ~ "' has allows_day_scope="
                ~ scope['allows_day_scope'] ~ " so day_column must "
                ~ ('be passed' if scope['allows_day_scope'] else 'be omitted')
            ) }}
        {%- endif -%}
    {%- endif -%}
and not exists (
        select 1
        from {{ exceptions_relation }} as ex
        where nullif(trim(ex.target_key), '') = '{{ target_key }}'
            and (
                -- a structural carve-out never expires; anything else needs a live
                -- expires_on, and a null never matches, so a malformed row keeps alerting
                coalesce(nullif(trim(ex.exception_kind), ''), '') = 'structural'
                or current_date() <= ex.expires_on
            )
            and (
                -- no entity_key scopes the exception to every row of the test
                nullif(trim(ex.entity_key), '') is null
                {%- for entity_column, column_expression in entity_columns.items() %}
                or (
                    nullif(trim(ex.entity_column), '') = '{{ entity_column }}'
                    and nullif(trim(ex.entity_key), '') = cast({{ column_expression }} as string)
                )
                {%- endfor %}
            )
            {%- if day_column is not none %}
            and (ex.day_from is null or {{ day_column }} >= ex.day_from)
            and (ex.day_to is null or {{ day_column }} <= ex.day_to)
            {%- endif %}
    )
{% endmacro %}


{% macro validate_test_exceptions(exceptions_relation) %}
    {#- Flags rows in exceptions_relation that can't do what their author intended; see docs/test_exceptions.md. -#}
    {%- set target_structs = [] -%}
    {%- set column_structs = [] -%}
    {%- if execute -%}
        {#- graph is only populated once execute is true; scoped to model.package_name so a
            downstream project's registry never picks up this package's own wired tests. -#}
        {%- for node_id in graph['nodes'] -%}
            {%- set n = graph['nodes'][node_id] -%}
            {%- if
                n['resource_type'] == 'test'
                and n['package_name'] == model.package_name
                and 'meta' in n
                and 'exception_scope' in n['meta']
            -%}
                {%- set scope = n['meta']['exception_scope'] -%}
                {%- do target_structs.append(
                    "struct('" ~ n['name'] ~ "' as target_key, "
                    ~ (scope['allows_day_scope'] | string | lower) ~ " as allows_day_scope)"
                ) -%}
                {%- for entity_column in scope['entity_columns'] -%}
                    {%- do column_structs.append(
                        "struct('" ~ n['name'] ~ "' as target_key, '" ~ entity_column ~ "' as entity_column)"
                    ) -%}
                {%- endfor -%}
            {%- endif -%}
        {%- endfor -%}
    {%- endif -%}

-- Registered targets and their scopable columns come from this project's own test
-- nodes as two lists, not one: a target with no entity columns still has to be
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
    from {{ exceptions_relation }} as ex
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
                then 'unregistered_target_key: no test in this project declares meta.exception_scope for it'
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
{% endmacro %}
