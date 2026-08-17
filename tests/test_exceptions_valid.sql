-- Guards seeds/public_test_exceptions.csv using the shared validate_test_exceptions
-- macro (see macros/test_exceptions.sql for what it checks, and for why the
-- registry it validates against is discovered by scanning this project's own test
-- nodes' meta.exception_scope rather than a hand-maintained dict).

{{ config(
    severity="error"
    , tags=["singular_test"]
    , enabled=var("is_singular_airflow_task") == "true"
    )
}}

{{ validate_test_exceptions(ref('public_test_exceptions')) }}
