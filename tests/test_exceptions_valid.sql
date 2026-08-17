-- Guards seeds/public_test_exceptions.csv using the shared validate_test_exceptions
-- macro (macros/test_exceptions.sql) -- see that macro's docstring for what it checks
-- and why it takes the registry and the seed relation as explicit arguments rather
-- than looking either up by name.

{{ config(
    severity="error"
    , tags=["singular_test"]
    , enabled=var("is_singular_airflow_task") == "true"
    )
}}

{{ validate_test_exceptions(test_exception_targets(), ref('public_test_exceptions')) }}
