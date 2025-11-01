{{ config(
    materialized='incremental',
    unique_key=["day", "account_id", "asset_code", "asset_issuer", "asset_type"],
    partition_by={
         "field": "day"
        , "data_type": "date"
        , "granularity": "day"
    },
    cluster_by=["asset_type", "asset_code", "asset_issuer"],
    incremental_predicates=["DBT_INTERNAL_DEST.day >= DATE('" ~ var('execution_date') ~ "')"]
    )
}}

with
    dt as (
        select dates as day
        {% if is_incremental() %}
            from unnest(generate_date_array(date('{{ var("batch_start_date") }}'), date_sub(date('{{ var("batch_end_date") }}'), interval 1 day))) as dates
        {% else %}
            from unnest(generate_date_array('2023-01-01', date('{{ var("batch_start_date") }}'))) as dates
        {% endif %}
    )

    , filtered_tl as (
        select
            tl.account_id
            , tl.asset_type
            , tl.asset_issuer
            , tl.asset_code
            , tl.selling_liabilities as balance
            , tl.valid_from
            , tl.valid_to
        from {{ ref('trustlines_snapshot') }} as tl
        where
            tl.deleted is false
            and tl.selling_liabilities > 0
            and tl.liquidity_pool_id = ''
            and date(tl.valid_from) <= (select max(day) from dt)
            and (tl.valid_to is null or date(tl.valid_to) >= (select min(day) from dt))

    )

    , filtered_acc as (
        select
            acc.account_id
            , 'native' as asset_type
            , '' as asset_issuer
            , '' as asset_code
            , acc.selling_liabilities as balance
            , acc.valid_from
            , acc.valid_to
        from {{ ref('accounts_snapshot') }} as acc
        where
            acc.deleted is false
            and acc.selling_liabilities > 0
            and date(acc.valid_from) <= (select max(day) from dt)
            and (acc.valid_to is null or date(acc.valid_to) >= (select min(day) from dt))
    )


    , aggregate as (
        select
            dt.day
            , tl.account_id
            , tl.asset_type
            , tl.asset_issuer
            , tl.asset_code
            , tl.balance
        from dt
        inner join filtered_tl as tl
            on
            dt.day >= date(tl.valid_from)
            and (dt.day < date(tl.valid_to) or tl.valid_to is null)

        union all

        select
            dt.day
            , acc.account_id
            , acc.asset_type
            , if(acc.asset_type = 'native', 'XLM', acc.asset_issuer) as asset_issuer
            , if(acc.asset_type = 'native', 'XLM', acc.asset_code) as asset_code
            , acc.balance
        from dt
        inner join filtered_acc as acc
            on
            dt.day >= date(acc.valid_from)
            and (dt.day < date(acc.valid_to) or acc.valid_to is null)
    )

select
    agg.day
    , agg.account_id
    , agg.asset_type
    , agg.asset_issuer
    , agg.asset_code
    , a.asset_contract_id as contract_id
    , agg.balance
from aggregate as agg
left join {{ ref('stg_assets') }} as a
    on agg.asset_type = a.asset_type
    and agg.asset_code = a.asset_code
    and agg.asset_issuer = a.asset_issuer
