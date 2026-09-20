-- Guards seeds/public_test_exceptions.csv -- see macros/test_exceptions.sql and
-- docs/test_exceptions.md for what it checks and why.

{{ config(
    severity="error"
    , tags=["singular_test"]
    , enabled=var("is_singular_airflow_task") == "true"
    )
}}

{#- Registry checks only where every wired test is enabled: off prod the prod-only tests
    are absent from `graph`, so their valid rows would read as unregistered. -#}
{{ validate_test_exceptions(ref('public_test_exceptions'), check_registration=(target.name == "prod")) }}
