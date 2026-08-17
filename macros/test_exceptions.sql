{#-
    Known-exception mechanism for data-quality tests, shared by this package and any
    project that installs it (e.g. stellar-dbt).

    A `test_exceptions`-shaped seed (here: `public_test_exceptions`,
    seeds/public_test_exceptions.csv) is the one place a project records known,
    accepted test failures, so a pipeline stops alerting on a situation already
    triaged. `exclude_test_exceptions` turns those rows into a predicate a singular
    test appends to its final `where`: an exception forgives *specific rows*, and
    the test keeps alerting on everything else.

    Rows come in two kinds. A `temporary` exception is an accepted failure with a
    required `expires_on`; when it passes, the exception stops applying and the test
    starts failing again, which is the review prompt. A `structural` one is a
    permanent carve-out that is correct by design (the XLM SAC publishing `native`
    as its symbol), and carries no expiry -- these are the hard-coded exclusions
    that used to live in the test SQL, where they were invisible to anyone not
    reading the file.

    There is no central registry macro. A test registers itself by declaring
    `meta={"exception_scope": {"entity_columns": [...], "allows_day_scope": bool}}`
    in its own `config()` block, right next to the test's own SQL -- not in a
    separate dict that has to be kept in sync by hand. `target_key` is never passed
    either: it is always `model.name`, i.e. the test's own name.

    Both `exclude_test_exceptions` and `validate_test_exceptions` read `config`/
    `model`/`graph` rather than taking a registry argument, and that is safe
    (unlike an earlier version of this file, which took the registry as an
    explicit argument specifically to avoid a DIFFERENT dbt gotcha -- see below)
    because `config` and `model` are bound to whichever NODE is currently
    compiling, not to whichever package physically defines the macro being
    executed. Verified empirically: a test in a downstream project, calling this
    macro qualified as `stellar_dbt_public.exclude_test_exceptions(...)`, sees ITS
    OWN `config.meta`, not this package's. Likewise `graph["nodes"]` exposes every
    project's test nodes regardless of which package's code is walking it, so
    `validate_test_exceptions` scopes its scan to `model.package_name` to build
    only the calling project's own registry.

    Two unrelated dbt/Jinja gotchas surfaced while building this, both worth
    knowing before touching this file:
      - An UNQUALIFIED macro call inside a macro's own body resolves against the
        package of the ORIGINAL CALLING NODE, not the package where that macro is
        physically defined. (This is why the previous version of this file took a
        `registry` argument instead of calling a no-arg `test_exception_targets()`
        internally, and why there is no private helper macro here even now.)
      - `config.get("meta", {})` and a `graph["nodes"][id]["meta"]` entry are
        Mapping-like but are NOT plain Python dicts, and dbt's sandboxed Jinja
        environment does not consider `.get()` (or `.values()` on `graph["nodes"]`
        itself) a safe method call on them -- it silently coerces to the object's
        string form first, so `.get(...)` fails with a wrong-and-confusing
        "'str object' has no attribute 'get'". Subscript (`d["key"]`) and `in` are
        both safe and used throughout this file instead. `graph` itself is also
        only populated when `execute` is true, so every graph scan is guarded with
        `{% if execute %}`.

    Wiring a new test:
      1. add `meta={"exception_scope": {"entity_columns": [...], "allows_day_scope": bool}}`
         to the test's own `config()` block
      2. call `exclude_test_exceptions` in the test's final `where`:
         `{{ exclude_test_exceptions(ref('test_exceptions'), entity_columns={...}) }}`
         (from outside this package, qualify: `stellar_dbt_public.exclude_test_exceptions(...)`)
-#}

{% macro exclude_test_exceptions(exceptions_relation, entity_columns={}, day_column=none) %}
    {#-
        Emit an `and not exists (...)` predicate that drops rows covered by a live
        exception. Fragment starts with `and`, so the caller needs a preceding
        condition (`where 1 = 1` when it has none of its own).

        exceptions_relation: the caller's own exceptions seed, e.g. ref('test_exceptions')
        entity_columns: {declared column name: SQL expression in this test};
            omit for a target with no entity to scope by, where only a day range
            or a whole-test suppression makes sense
        day_column: SQL expression for the row's data day, or none

        target_key is always the calling test's own name (model.name); its
        declared scope is always that test's own config.meta.exception_scope. Both
        come from context, never from an argument -- see this file's docstring for
        why that is safe here despite the cross-package macro-resolution gotcha
        that made the PREVIOUS version of this macro take a registry argument.

        The validation below only runs when execute is true. dbt renders every
        node's Jinja at least twice -- an early pass (execute=false) used to
        extract the dependency graph, where a node's OWN config() calls are not
        yet reflected in config.get(...), and a later pass (execute=true, the one
        that produces the SQL dbt actually compiles/runs/lints) where they are.
        Skipping validation on the early pass does not weaken it: the SQL emitted
        below does not depend on config.meta at all (target_key is model.name,
        entity_columns/day_column are macro arguments), so it renders identically
        either way, and the validation still runs on every real compile, test, and
        build.
    -#}
    {%- set target_key = model.name -%}
    {%- if execute -%}
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
        where ex.target_key = '{{ target_key }}'
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
    {#-
        Full singular-test body guarding a `test_exceptions`-shaped seed against rows
        that cannot do what their author intended: a target no test in THIS project
        declares, an entity_column the target does not expose, a day scope on a
        target with no day column, a half-filled scope, a missing reason/owner, or
        an expiry that contradicts the exception_kind. A silently inert exception
        row is the main failure mode of a table like this -- the alert keeps firing
        while the row looks like it should have stopped it, and nobody re-reads a
        row they believe works.

        Structural checks only. An *expired* temporary row needs no alert of its
        own: the exception stops applying and the underlying test starts failing
        again on its next run, which is exactly the review prompt we want.

        exceptions_relation: the caller's own exceptions seed, e.g. ref('test_exceptions')

        The registry is not passed in -- it is discovered by scanning graph["nodes"]
        for test nodes in THIS macro's calling project (model.package_name) that
        declare meta.exception_scope. A caller wraps this in its own test file as:
            {{ config(...) }}
            {{ validate_test_exceptions(ref('test_exceptions')) }}
        (from outside this package, qualify: stellar_dbt_public.validate_test_exceptions(...))
    -#}
    {%- set target_structs = [] -%}
    {%- set column_structs = [] -%}
    {%- if execute -%}
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
