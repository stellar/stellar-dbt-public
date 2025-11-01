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
)}}

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
            , tl.balance
            , tl.liquidity_pool_id
            , tl.valid_from
            , tl.valid_to
        from {{ ref('trustlines_snapshot') }} as tl
        where
            tl.liquidity_pool_id != ''
            and tl.deleted is false
            and date(tl.valid_from) <= (select max(day) from dt)
            and (tl.valid_to is null or date(tl.valid_to) >= (select min(day) from dt))
    )

    , filtered_lp as (
        select lp.*
        from {{ ref('liquidity_pools_snapshot') }} as lp
        where
            lp.deleted is false
            and date(lp.valid_from) <= (select max(day) from dt)
            and (lp.valid_to is null or date(lp.valid_to) >= (select min(day) from dt))
    )

    , all_tl as (
        select
            dt.day
            , ftl.* except (valid_from, valid_to)
        from dt
        inner join filtered_tl as ftl
            on
            dt.day >= date(ftl.valid_from)
            and (dt.day < date(ftl.valid_to) or ftl.valid_to is null)
    )

    , all_lp as (
        select
            dt.day
            , flp.* except (valid_from, valid_to)
        from dt
        inner join filtered_lp as flp
            on
            dt.day >= date(flp.valid_from)
            and (dt.day < date(flp.valid_to) or flp.valid_to is null)
    )

    , joined as (
        select
            all_tl.day
            , all_tl.account_id
            , all_lp.asset_a_type
            , all_lp.asset_a_issuer
            , all_lp.asset_a_code
            , (all_tl.balance / all_lp.pool_share_count) * all_lp.asset_a_amount as asset_a_amount
            , all_lp.asset_b_type
            , all_lp.asset_b_issuer
            , all_lp.asset_b_code
            , (all_tl.balance / all_lp.pool_share_count) * all_lp.asset_b_amount as asset_b_amount
        from all_tl
        left join all_lp
            on all_tl.liquidity_pool_id = all_lp.liquidity_pool_id
            and all_tl.day = all_lp.day
        where all_lp.pool_share_count != 0
    )

    , account_from_balances as (
        select
            j.day
            , j.account_id
            , j.asset_a_type as asset_type
            , j.asset_a_issuer as asset_issuer
            , j.asset_a_code as asset_code
            , sum(j.asset_a_amount) as balance
        from joined as j
        group by 1, 2, 3, 4, 5
    )

    , account_to_balances as (
        select
            j.day
            , j.account_id
            , j.asset_b_type as asset_type
            , j.asset_b_issuer as asset_issuer
            , j.asset_b_code as asset_code
            , sum(j.asset_b_amount) as balance
        from joined as j
        group by 1, 2, 3, 4, 5
    )

    , all_balances as (
        select * from account_from_balances
        union all
        select * from account_to_balances
    )

    , aggregate as (
        select
            day
            , account_id
            , asset_type
            , if(asset_type = 'native', 'XLM', asset_issuer) as asset_issuer
            , if(asset_type = 'native', 'XLM', asset_code) as asset_code
            , sum(balance) as balance
        from all_balances
        group by 1, 2, 3, 4, 5
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
