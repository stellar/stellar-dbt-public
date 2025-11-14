{% macro calc_ohlc(
    relation,
    ts_col='updated_at',
    price_col='close_usd',
    partition_cols=['asset_code', 'asset_issuer', 'asset_type', 'asset_contract_id']
) %}

with raw_table as (

    select
        date({{ ts_col }}) as day,
        {%- for col in partition_cols %}
            {{ col }}{% if not loop.last %},{% endif %}
        {%- endfor %},

        first_value({{ price_col }}) over w as open_usd,
        max({{ price_col }}) over w as high_usd,
        min({{ price_col }}) over w as low_usd,
        last_value({{ price_col }}) over w as close_usd

    from {{ relation }}

    window w as (
        partition by
            date({{ ts_col }}),
            {%- for col in partition_cols %}
                {{ col }}{% if not loop.last %},{% endif %}
            {%- endfor %}
        order by {{ ts_col }}
        rows between unbounded preceding and unbounded following
    )
)

select distinct *
from raw_table

{% endmacro %}
