{#
  Query comment rendered as BigQuery job labels (query-comment.job-label in
  dbt_project.yml). dbt-bigquery turns each JSON key into a label and adds
  dbt_invocation_id itself. Labels are lowercased, chars outside [a-z0-9_-]
  become "_" and values are cut at 63 chars, so node_id can truncate for long
  test ids; node_name / resource_type / package_name stay intact.
  AIRFLOW_* are set by the stellar-etl-airflow dbt task env and absent elsewhere.
#}
{% macro query_comment(node) %}
    {%- set labels = {
        "app": "dbt",
        "dbt_version": dbt_version,
        "profile_name": target.get("profile_name"),
        "target_name": target.get("target_name"),
    } -%}
    {%- if node is not none -%}
        {%- do labels.update({
            "node_id": node.unique_id,
            "node_name": node.name,
            "resource_type": node.resource_type,
            "package_name": node.package_name,
            "materialized": node.config.materialized,
        }) -%}
    {%- else -%}
        {%- do labels.update({"connection_name": connection_name}) -%}
    {%- endif -%}
    {%- for env_name in ["AIRFLOW_DAG_ID", "AIRFLOW_TASK_ID", "AIRFLOW_RUN_ID"] -%}
        {%- do labels.update({env_name | lower: env_var(env_name, "")}) -%}
    {%- endfor -%}
    {%- set out = {} -%}
    {%- for key, value in labels.items() if value | string -%}
        {%- do out.update({key: value | string}) -%}
    {%- endfor -%}
    {{ return(tojson(out)) }}
{% endmacro %}
