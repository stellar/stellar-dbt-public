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

    `exclude_test_exceptions` and `validate_test_exceptions` are deliberately
    parameterized rather than looking up a registry or a `ref()` by a fixed name:
    dbt's macro-override rule means an unqualified macro call always resolves to the
    ROOT project's definition of that name, even when the call happens inside this
    package's own code. If these macros called a no-arg `test_exception_targets()`
    or hardcoded `ref('public_test_exceptions')` internally, a project that installs
    this package and defines ITS OWN same-named registry macro would silently
    override the lookup used by this package's OWN tests when they run as a
    dependency -- the exact "which repo's registry did this resolve to" bug this
    mechanism exists to prevent. Passing the registry and the relation in as
    already-evaluated arguments sidesteps that: nothing inside these macros does an
    ambient name lookup, so there is nothing left for another project's macro of the
    same name to shadow.

    Each project (this one, or a downstream installer) keeps its OWN
    `test_exception_targets()` registry -- the set of wired tests genuinely differs
    per project, so that part is not shared -- and its own `test_exceptions`-shaped
    seed. Wiring a new test:
      1. add it to that project's `test_exception_targets()`, naming the columns an
         exception may be scoped to and whether the test exposes a data day
      2. call `exclude_test_exceptions` in the test's final `where`, passing that
         project's own `test_exception_targets()` and `ref()` explicitly:
         `{{ exclude_test_exceptions('my_test', test_exception_targets(), ref('test_exceptions'), entity_columns={...}) }}`
         (from outside this package, qualify both: `stellar_dbt_public.exclude_test_exceptions(...)`)
-#}

{% macro test_exception_targets() %}
    {#-
        Every singular test in tests/, and what an exception for it may be scoped
        by. `entity_columns` are alternatives, not a composite key: a row names one
        of them in `entity_column`. `allows_day_scope` is false only where the test
        has no day to scope by. Which day each test scopes on is listed in
        docs/test_exceptions.md and visible at the call site.

        tests/test_exceptions_valid.sql is deliberately absent -- excepting the
        validator would let a malformed row silence the check that catches it. The
        generic tests in tests/generic/ are absent for a different reason: they run
        once per model, so a row would have to name the model as well as the test,
        which this registry does not model yet.
    -#}
    {{ return({
        'bucketlist_db_size_check': {
            'entity_columns': [],
            'allows_day_scope': true,
        },
        'eho_by_ops': {
            'entity_columns': ['batch_id'],
            'allows_day_scope': true,
        },
        'int_token_transfer_enrichment_amount_matches_current_metadata': {
            'entity_columns': ['contract_id'],
            'allows_day_scope': true,
        },
        'ledger_sequence_increment': {
            'entity_columns': ['ledger_id', 'batch_id'],
            'allows_day_scope': true,
        },
        'no_missing_days_in_snapshot': {
            'entity_columns': ['table_name'],
            'allows_day_scope': true,
        },
        'no_missing_ledgers': {
            'entity_columns': ['table_name'],
            'allows_day_scope': true,
        },
        'num_txns_and_ops': {
            'entity_columns': ['batch_id'],
            'allows_day_scope': true,
        },
        'sac_asset_code_matches_metadata_symbol': {
            'entity_columns': ['contract_id'],
            'allows_day_scope': false,
        },
        'token_transfers_no_negative_circulating_supply': {
            'entity_columns': ['contract_id'],
            'allows_day_scope': false,
        },
    }) }}
{% endmacro %}


{% macro exclude_test_exceptions(target_key, registry, exceptions_relation, entity_columns={}, day_column=none) %}
    {#-
        Emit an `and not exists (...)` predicate that drops rows covered by a live
        exception. Fragment starts with `and`, so the caller needs a preceding
        condition (`where 1 = 1` when it has none of its own).

        target_key: the row's `target_key` in the seed; must be a key in `registry`
        registry: the caller's own test_exception_targets(), passed explicitly
        exceptions_relation: the caller's own exceptions seed, e.g. ref('test_exceptions')
        entity_columns: {registered column name: SQL expression in this test};
            omit for a target with no entity to scope by, where only a day range
            or a whole-test suppression makes sense
        day_column: SQL expression for the row's data day, or none

        The registered-shape validation below is inlined rather than pulled into its
        own helper macro on purpose: dbt resolves an unqualified macro call inside a
        macro's body against the ORIGINAL CALLING NODE's package, not the package
        where that macro is physically defined. A helper macro defined here but
        called unqualified from inside this macro's body would come back
        "undefined" the moment a downstream project calls this macro qualified
        (`stellar_dbt_public.exclude_test_exceptions(...)`), because that downstream
        project's package has no macro of the helper's name. Keeping everything in
        one macro body sidesteps that entirely.
    -#}
    {%- if target_key not in registry -%}
        {{ exceptions.raise_compiler_error(
            "exclude_test_exceptions: '" ~ target_key ~ "' is not registered in the caller's test_exception_targets()"
        ) }}
    {%- endif -%}
    {%- set registered = registry[target_key] -%}
    {%- if entity_columns.keys() | list | sort != registered['entity_columns'] | list | sort -%}
        {{ exceptions.raise_compiler_error(
            "exclude_test_exceptions: '" ~ target_key ~ "' passed columns "
            ~ (entity_columns.keys() | list | sort | join(', '))
            ~ " but test_exception_targets() registers "
            ~ (registered['entity_columns'] | list | sort | join(', '))
        ) }}
    {%- endif -%}
    {%- if (day_column is not none) != registered['allows_day_scope'] -%}
        {{ exceptions.raise_compiler_error(
            "exclude_test_exceptions: '" ~ target_key ~ "' has allows_day_scope="
            ~ registered['allows_day_scope'] ~ " so day_column must "
            ~ ('be passed' if registered['allows_day_scope'] else 'be omitted')
        ) }}
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


{% macro validate_test_exceptions(registry, exceptions_relation) %}
    {#-
        Full singular-test body guarding a `test_exceptions`-shaped seed against rows
        that cannot do what their author intended: a target `registry` doesn't
        declare, an entity_column the target does not expose, a day scope on a
        target with no day column, a half-filled scope, a missing reason/owner, or
        an expiry that contradicts the exception_kind. A silently inert exception
        row is the main failure mode of a table like this -- the alert keeps firing
        while the row looks like it should have stopped it, and nobody re-reads a
        row they believe works.

        Structural checks only. An *expired* temporary row needs no alert of its
        own: the exception stops applying and the underlying test starts failing
        again on its next run, which is exactly the review prompt we want.

        registry: the caller's own test_exception_targets(), passed explicitly
        exceptions_relation: the caller's own exceptions seed, e.g. ref('test_exceptions')

        A caller wraps this in its own test file as:
            {{ config(...) }}
            {{ validate_test_exceptions(test_exception_targets(), ref('test_exceptions')) }}
        (from outside this package, qualify: stellar_dbt_public.validate_test_exceptions(...))
    -#}
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

-- Registered targets and their scopable columns come from the caller's registry as
-- two lists, not one: a target with no entity columns still has to be registered,
-- or its rows would look unregistered rather than unscopable.
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
{% endmacro %}
