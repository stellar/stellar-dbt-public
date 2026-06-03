{{ config(
    materialized='incremental',
    incremental_strategy="insert_overwrite",
    unique_key=["day", "account_id", "asset_code", "asset_issuer", "asset_type"],
    partition_by={
         "field": "day"
        , "data_type": "date"
        , "granularity": "day"
        , "copy_partitions": true
    },
    cluster_by=["asset_type", "asset_code", "asset_issuer"]
) }}

{# Inline the batch window as date literals (instead of subqueries on a date
   spine) so BigQuery can prune the valid_to month partitions on the snapshot
   tables. #}
{% if is_incremental() %}
    {% set min_day = var('batch_start_date') %}
{% else %}
    {% set min_day = '2023-01-01' %}
{% endif %}

with
    filtered_tl as (
        select
            tl.account_id
            , tl.asset_type
            , tl.asset_issuer
            , tl.asset_code
            , tl.balance
            , date(tl.valid_from) as valid_from_day
            , date(tl.valid_to) as valid_to_day
        from {{ ref('trustlines_snapshot') }} as tl
        where
            tl.liquidity_pool_id = ''
            and tl.deleted is false
            and tl.valid_from < timestamp(date('{{ var("batch_end_date") }}'))
            and (tl.valid_to is null or tl.valid_to >= timestamp(date('{{ min_day }}')))
    )

    , filtered_acc as (
        select
            acc.account_id
            , 'native' as asset_type
            , 'XLM' as asset_issuer
            , 'XLM' as asset_code
            , acc.balance
            , date(acc.valid_from) as valid_from_day
            , date(acc.valid_to) as valid_to_day
        from {{ ref('accounts_snapshot') }} as acc
        where
            acc.deleted is false
            and acc.valid_from < timestamp(date('{{ var("batch_end_date") }}'))
            and (acc.valid_to is null or acc.valid_to >= timestamp(date('{{ min_day }}')))
    )

    -- explode each validity interval into the days it covers within the batch
    -- window. a row is counted for a day only if it was valid for the entire
    -- day: from its valid_from date through the day before its valid_to date.
    , daily_balances as (
        select
            day
            , tl.account_id
            , tl.asset_type
            , tl.asset_issuer
            , tl.asset_code
            , tl.balance
        from filtered_tl as tl
        cross join
            unnest(
                generate_date_array(
                    greatest(tl.valid_from_day, date('{{ min_day }}'))
                    , least(
                        coalesce(date_sub(tl.valid_to_day, interval 1 day), date_sub(date('{{ var("batch_end_date") }}'), interval 1 day))
                        , date_sub(date('{{ var("batch_end_date") }}'), interval 1 day)
                    )
                )
            ) as day

        union all

        select
            day
            , acc.account_id
            , acc.asset_type
            , acc.asset_issuer
            , acc.asset_code
            , acc.balance
        from filtered_acc as acc
        cross join unnest(
            generate_date_array(
                greatest(acc.valid_from_day, date('{{ min_day }}'))
                , least(
                    coalesce(date_sub(acc.valid_to_day, interval 1 day), date_sub(date('{{ var("batch_end_date") }}'), interval 1 day))
                    , date_sub(date('{{ var("batch_end_date") }}'), interval 1 day)
                )
            )
        ) as day
    )

select
    agg.day
    , agg.account_id
    , agg.asset_type
    , agg.asset_issuer
    , agg.asset_code
    -- Note: There will be some null contract_ids from this trustlines aggregate
    -- This is because there are trustlines that have been created for assets that have had
    -- zero asset value movement meaning they won't have any events in token_transfers.
    -- Because there are no events in token_transfers there is nothing for stg_assets to create
    -- the asset --> contract_id association hence there being null contract_ids in this agg.
    -- This will be fixed in the future when stellar-etl adds contract_ids for assets.
    , a.asset_contract_id as contract_id
    , agg.balance
from daily_balances as agg
left join {{ ref('stg_assets') }} as a
    on agg.asset_type = a.asset_type
    and agg.asset_code = a.asset_code
    and agg.asset_issuer = a.asset_issuer
