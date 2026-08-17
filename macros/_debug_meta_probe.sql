{% macro _debug_meta_probe() %}
    {%- set own_meta = config.get("meta", {}) -%}
    {%- set own_probe = own_meta["probe_marker"] if "probe_marker" in own_meta else "MISSING" -%}
    {%- set matches = [] -%}
    {%- if execute -%}
        {%- for node_id in graph["nodes"] -%}
            {%- set n = graph["nodes"][node_id] -%}
            {%- if n["resource_type"] == "test" and "meta" in n and "probe_marker" in n["meta"] -%}
                {%- do matches.append(n["package_name"] ~ "." ~ n["name"] ~ "=" ~ n["meta"]["probe_marker"]) -%}
            {%- endif -%}
        {%- endfor -%}
    {%- endif -%}
select
    '{{ model.package_name }}.{{ model.name }}' as calling_node
    , '{{ own_probe }}' as own_meta_seen
    , '{{ matches | sort | join(" | ") }}' as graph_scan_result
{% endmacro %}
