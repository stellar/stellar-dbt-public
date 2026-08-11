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
-- where clause. Every statement that reads or writes the target needs it -- the delete, the
-- reopen, the source read and the boundary read -- because one missing it would corrupt or
-- delete entities the caller never asked to touch. Callers that need an aliased variant call
-- this again with a table_alias rather than hand-rolling the predicate.
--
-- The filter is always on source_unique_key[0]. For a snapshot with a composite key that
-- means the values name a *group* of entities rather than one:
--
--     trustlines_snapshot                (account_id, asset_type, asset_issuer, asset_code,
--                                         liquidity_pool_id)  -> every trustline of an account
--     recognized_asset_prices_snapshot   (asset_code, asset_issuer, asset_type)
--                                                             -> every issuer/type of a code
--     contract_data_snapshot             (contract_id, ledger_key_hash)
--                                                             -> every ledger key of a contract
--
-- That is a scope reducer, not an entity selector, and it stays correct because the predicate
-- is entity-constant: a key column has one value for all of an entity's rows, so every row of
-- a matched entity is matched and every row of an unmatched entity is not. The window
-- functions in calculate_snapshot_diff all partition by the *full* key, so a matched entity is
-- grouped and chained exactly as it would be in an unfiltered run.
--
-- Filtering on a column outside source_unique_key would break that -- the predicate could
-- split an entity's rows, and the windows would then compute over a mutilated set -- so the
-- column is never caller supplied.
--
-- A null in the filter column means the entity is not selected: it fails the IN in all four
-- statements alike, so it is left untouched rather than half rebuilt. Every current
-- source_unique_key[0] carries a not_null test.
#}

{%- set keys = config.get('snapshot_keys', var('snapshot_keys', none)) -%}

{%- if keys is none or keys == '' or keys == [] -%}
    {{ return('') }}
{%- endif -%}

{%- if source_unique_key_cols | length == 0 -%}
    {%- do exceptions.raise_compiler_error(
        "snapshot_keys needs a source_unique_key to filter on, but none is configured"
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
