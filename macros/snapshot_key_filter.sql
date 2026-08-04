{% macro snapshot_key_filter(source_unique_key_cols, table_alias=none) -%}

{#
-- Build the optional predicate that scopes a snapshot run to specific entities, so a
-- rebuild can target one asset rather than the whole table. Returns '' when no filter is
-- requested.
--
-- Set it with the snapshot_keys var, as a list or a comma separated string:
--     --vars '{"snapshot_keys": ["CONTRACT_A", "CONTRACT_B"]}'
--     --vars '{"snapshot_keys": "CONTRACT_A,CONTRACT_B"}'
--
-- The returned fragment always begins with "and " so callers can append it to an existing
-- where clause. It is built once per run and threaded into every statement that reads or
-- writes the target: the delete, the reopen, the source read and the boundary read.
-- A filter missing from any one of those would corrupt or delete entities the caller never
-- asked to touch, so callers must not re-derive it.
--
-- Only single column unique keys are supported. trustlines_snapshot is the one snapshot with
-- a composite key, and matching those keys is unsafe until their nulls are handled.
#}

{%- set keys = config.get('snapshot_keys', var('snapshot_keys', none)) -%}

{%- if keys is none or keys == '' or keys == [] -%}
    {{ return('') }}
{%- endif -%}

{%- if source_unique_key_cols | length > 1 -%}
    {%- do exceptions.raise_compiler_error(
        "snapshot_keys is only supported for a single column source_unique_key, but "
        ~ source_unique_key_cols | join(', ') ~ " has " ~ source_unique_key_cols | length ~ " columns"
    ) -%}
{%- endif -%}

{%- if keys is string -%}
    {%- set key_values = keys.split(',') -%}
{%- else -%}
    {%- set key_values = keys -%}
{%- endif -%}

{%- set quoted_values = [] -%}
{%- for key_value in key_values -%}
    {%- set trimmed = key_value | string | trim -%}
    {%- if trimmed != '' -%}
        {%- if "'" in trimmed -%}
            {%- do exceptions.raise_compiler_error(
                "snapshot_keys values must not contain quotes, got " ~ trimmed
            ) -%}
        {%- endif -%}
        {%- do quoted_values.append("'" ~ trimmed ~ "'") -%}
    {%- endif -%}
{%- endfor -%}

{%- if quoted_values | length == 0 -%}
    {{ return('') }}
{%- endif -%}

{%- set key_column = adapter.quote(source_unique_key_cols[0]) -%}
{%- set qualified_column = (table_alias ~ '.' ~ key_column) if table_alias else key_column -%}

{{ return(' and ' ~ qualified_column ~ ' in (' ~ quoted_values | join(', ') ~ ')') }}

{%- endmacro %}
