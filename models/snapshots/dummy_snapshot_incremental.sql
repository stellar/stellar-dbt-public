-- depends_on: {{ ref('stg_dummy') }}
{%- set temp_target_table = config.get('temp_target_table') -%}

{{ " " }}
SELECT * from {{ this.project ~ '.' ~ this.schema ~ '.' ~  temp_target_table }}
