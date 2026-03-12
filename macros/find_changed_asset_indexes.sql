/*
    Decodes a hex bitmask (LSB-first per byte) into an array of set bit positions.
    Used by reflector price models to determine which asset indices have updated prices.

    Example: mask_hex = 'd6bf080240...'
        byte 0xD6 = 11010110 → bits 1,2,4,6,7 are set
        byte 0xBF = 10111111 → bits 8,9,10,11,12,13,15 are set
        ...
    Returns: [1, 2, 4, 6, 7, 8, 9, 10, 11, 12, 13, 15, ...]

    Args:
        mask_hex_column: a column reference containing the hex mask string

    Usage:
        unnest({{ find_changed_asset_indexes('mask_hex') }}) as asset_index with offset as vec_index
*/

{% macro find_changed_asset_indexes(mask_hex_column) %}
(
    select array_agg(bit_pos order by bit_pos)
    from unnest(generate_array(0, length({{ mask_hex_column }}) * 4 - 1)) as bit_pos
    inner join (
        select hex_char, int_val
        from unnest(['0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f']) as hex_char with offset as int_val
    ) as h
        on h.hex_char = substr(
            {{ mask_hex_column }}
            -- byte position * 2, then pick low nibble (+2) for bits 0-3 or high nibble (+1) for bits 4-7
            , cast(floor(bit_pos / 8) as int64) * 2 + (case when mod(bit_pos, 8) < 4 then 2 else 1 end)
            , 1
        )
    where (h.int_val >> mod(bit_pos, 4)) & 1 = 1
)
{% endmacro %}
