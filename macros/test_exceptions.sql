{#-
    Known-exception mechanism for this package's data-quality tests.

    `public_test_exceptions` (seeds/public_test_exceptions.csv) is the one place we record known,
    accepted test failures, so a pipeline stops alerting on a situation we have
    already triaged. `exclude_test_exceptions` turns those rows into a predicate a
    singular test appends to its final `where`: an exception forgives *specific
    rows*, and the test keeps alerting on everything else.

    Rows come in two kinds. A `temporary` exception is an accepted failure with a
    required `expires_on`; when it passes, the exception stops applying and the test
    starts failing again, which is the review prompt. A `structural` one is a
    permanent carve-out that is correct by design (the XLM SAC publishing `native`
    as its symbol), and carries no expiry -- these are the hard-coded exclusions
    that used to live in the test SQL, where they were invisible to anyone not
    reading the file.

    A test opts in by registering in `test_exception_targets` and calling
    `exclude_test_exceptions`. The registry is what lets
    tests/test_exceptions_valid.sql reject a row that would silently forgive
    nothing -- the main failure mode of a table like this. A typo'd
    `entity_column` is a caught error, not a no-op.

    Wiring a new test:
      1. add it to `test_exception_targets` below, naming the columns an
         exception may be scoped to and whether the test exposes a data day
      2. call `exclude_test_exceptions` in the test's final `where`, mapping each
         registered column name to the SQL expression that produces it
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


{% macro exclude_test_exceptions(target_key, entity_columns={}, day_column=none) %}
    {#-
        Emit an `and not exists (...)` predicate that drops rows covered by a live
        exception. Fragment starts with `and`, so the caller needs a preceding
        condition (`where 1 = 1` when it has none of its own).

        target_key: the row's `target_key` in the seed; must be registered
        entity_columns: {registered column name: SQL expression in this test};
            omit for a target with no entity to scope by, where only a day range
            or a whole-test suppression makes sense
        day_column: SQL expression for the row's data day, or none
    -#}
    {%- set registry = test_exception_targets() -%}
    {%- if target_key not in registry -%}
        {{ exceptions.raise_compiler_error(
            "exclude_test_exceptions: '" ~ target_key ~ "' is not registered in test_exception_targets()"
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
        from {{ ref('public_test_exceptions') }} as ex
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
