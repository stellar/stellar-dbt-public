{% macro snapshot_chunk_ranges(start_date, end_date, chunk_months) -%}

{#
-- Split [start_date, end_date) into consecutive chunks of chunk_months, returned as a list
-- of [chunk_start, chunk_end] yyyy-mm-dd pairs. Chunk ends are non-inclusive.
--
-- The first chunk begins at start_date; every later chunk begins on the first of a month,
-- so only the first and last chunks can be shorter than chunk_months. Chunks are built in
-- ascending order because each one reads the version the previous chunk left open.
#}

{%- set dt = modules.datetime -%}
{%- set start = dt.date(start_date[0:4] | int, start_date[5:7] | int, start_date[8:10] | int) -%}
{%- set end = dt.date(end_date[0:4] | int, end_date[5:7] | int, end_date[8:10] | int) -%}

{%- if chunk_months is not number or chunk_months < 1 -%}
    {%- do exceptions.raise_compiler_error(
        "snapshot_chunk_months must be a positive whole number, got " ~ chunk_months
    ) -%}
{%- endif -%}

{%- set ranges = [] -%}

{%- if start < end -%}
    {#-- generous upper bound on the loop; the guard below is what actually ends it --#}
    {%- set total_months = (end.year - start.year) * 12 + (end.month - start.month) + 1 -%}
    {%- set max_chunks = (total_months // chunk_months) + 2 -%}
    {%- set ns = namespace(cursor=start) -%}

    {%- for _ in range(0, max_chunks) -%}
        {%- if ns.cursor < end -%}
            {%- set months = ns.cursor.month - 1 + chunk_months -%}
            {%- set next_boundary = dt.date(ns.cursor.year + (months // 12), (months % 12) + 1, 1) -%}
            {%- set chunk_end = next_boundary if next_boundary < end else end -%}
            {%- do ranges.append([
                ns.cursor.strftime('%Y-%m-%d'),
                chunk_end.strftime('%Y-%m-%d')
            ]) -%}
            {%- set ns.cursor = next_boundary -%}
        {%- endif -%}
    {%- endfor -%}
{%- endif -%}

{{ return(ranges) }}

{%- endmacro %}
