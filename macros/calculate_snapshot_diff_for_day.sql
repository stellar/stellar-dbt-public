{% macro calculate_snapshot_diff_for_day(
    source_name,
    target_name,
    source_start_date,
    source_end_date,
    updated_at_col_name,
    valid_from_col_name,
    valid_to_col_name,
    source_unique_key_cols
) -%}

{#
-- Calculate snapshot diff for a given day
-- Compare source and target(if target exist)
-- Return the diff of records: New source data, new records for existing target data, updated version of target data
#}

WITH source_ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY
               {{ " " }}
                    {%- for key in source_unique_key_cols -%}
                        {{ key }}
                        {{ " , " if not loop.last }}
                    {%- endfor -%}
               ORDER BY {{ updated_at_col_name }} DESC
           ) AS row_num
    FROM {{ ref(source_name) }}
    WHERE DATE({{ updated_at_col_name }}) >= DATE({{ source_start_date }})
      AND DATE({{ updated_at_col_name }}) < DATE({{ source_end_date }})
),

source_deduped AS (
    SELECT * EXCEPT (row_num),
    -- Add two columns to normalize source and target datasets
           CAST({{ updated_at_col_name }} AS TIMESTAMP) AS {{ valid_from_col_name }},
           CAST(NULL AS TIMESTAMP) AS {{ valid_to_col_name }}
    FROM source_ranked
    WHERE row_num = 1
)

{%- if not target_name %}
    {#-- Target does not exist, therefore source data becomes diff as is --#}
    SELECT *
    FROM source_deduped
{% else %}
    {#-- Target exists, therefore join source and target data --#}
    , target_deduped AS (
        SELECT *
        FROM {{ target_name }}
        WHERE {{ valid_to_col_name }} IS NULL
    ),

    joined_data AS (
        SELECT
            s.*,
            {%- for key in source_unique_key_cols -%}
                t.{{ key }} AS t_{{ key }},
            {%- endfor -%}
            t.{{ valid_from_col_name }} AS t_{{ valid_from_col_name }}
        FROM source_deduped s
        LEFT JOIN target_deduped t
            ON (
                {%- for key in source_unique_key_cols -%}
                    s.{{ key }} = t.{{ key }}
                    {{ " and " if not loop.last }}
                {%- endfor -%}
            )
    ),

    {#-- Set 1: New records to be inserted as is --#}
    new_source_records as (
        SELECT
            * EXCEPT (
                {%- for key in source_unique_key_cols -%}
                    t_{{ key }},
                {%- endfor -%}
                t_{{ valid_from_col_name }}
            )
        FROM joined_data j
        WHERE
        (
                {%- for key in source_unique_key_cols -%}
                    j.t_{{ key }} IS NULL
                    {{ " and " if not loop.last }}
                {%- endfor -%}
        )
    ),

    {#-- Set 2: New version of existing target records --#}
    new_source_records_for_modified_target_records as (
        SELECT
            * EXCEPT (
                {%- for key in source_unique_key_cols -%}
                    t_{{ key }},
                {%- endfor -%}
                t_{{ valid_from_col_name }}
            )
        FROM joined_data j
        WHERE
            (
            {%- for key in source_unique_key_cols -%}
                j.t_{{ key }} IS NOT NULL
                {{ " and " if not loop.last }}
            {%- endfor -%}
            )
            AND j.{{ valid_from_col_name }} > j.t_{{ valid_from_col_name }}
    ),

    {#-- Set 3: Expire existing target records --#}
    modified_target_records as (
        SELECT
            t.* EXCEPT ({{ valid_to_col_name }}),
            j.{{ valid_from_col_name }} AS {{ valid_to_col_name }}
        FROM joined_data j
        JOIN target_deduped t
            ON (
                {%- for key in source_unique_key_cols -%}
                    j.t_{{ key }} = t.{{ key }}
                    {{ " and " if not loop.last }}
                {%- endfor -%}
            )
            AND j.t_{{ valid_from_col_name }} = t.{{ valid_from_col_name }}
        WHERE j.{{ valid_from_col_name }} > j.t_{{ valid_from_col_name }}
    )

    {#-- Union set 1, 2 and 3 to get the full diff --#}
    SELECT * FROM new_source_records
    UNION ALL
    SELECT * FROM new_source_records_for_modified_target_records
    UNION ALL
    SELECT * FROM modified_target_records

{% endif %}

{%- endmacro %}
