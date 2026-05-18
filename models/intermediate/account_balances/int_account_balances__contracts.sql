{% set meta_config = {
    "unique_key": ["day", "account_id", "contract_id"],
    "partition_by": {
         "field": "day"
        , "data_type": "date"
        , "granularity": "day"
    },
    "cluster_by": ["account_id", "contract_id"],
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}


-- This SQL calculates the C address balances and C/G balances for custom contract tokens (not SAC).

-- Note: This currently doesn't need to be incremental because the amount of C address and custom contract token balances are small
-- re-aggregating from the start of smart contracts (2024-02-20) to current is very quick and not compute intensive.
-- TODO: account_ids should really be named addresses; This can be refactored in the future if needed
with
    -- Amounts should be added when assets are sent to the account
    token_transfers_to as (
        select
            date(tt.closed_at) as day
            , tt.to as account_id
            , tt.contract_id
            -- Note that 10^-7 is the default precision for Stellar assets. Recognized assets with default precision will have null token_precision.
            , sum(safe_cast(tt.amount_raw as numeric) * pow(10, coalesce(-safe_cast(metadata.decimal as int64), -7))) as balance
        from {{ ref('stg_token_transfers_raw') }} as tt
        left join {{ ref('int_asset_metadata') }} as metadata
            on tt.contract_id = metadata.contract_id
        where
            true
            and tt.to is not null
            -- Only count C addresses for SACs or custom contract tokens.
            -- Custom contract tokens won't have an asset_type and will contain both C and G addresses
            and (tt.to like 'C%' or tt.asset_type = '')
        group by 1, 2, 3
    )

    -- Amounts should be subtracted when assets are sent from the account
    , token_transfers_from as (
        select
            date(tt.closed_at) as day
            , tt.`from` as account_id
            , tt.contract_id
            -- Note that 10^-7 is the default precision for Stellar assets. Recognized assets with default precision will have null token_precision.
            , -sum(safe_cast(tt.amount_raw as numeric) * pow(10, coalesce(-safe_cast(metadata.decimal as int64), -7))) as balance
        from {{ ref('stg_token_transfers_raw') }} as tt
        left join {{ ref('int_asset_metadata') }} as metadata
            on tt.contract_id = metadata.contract_id
        where
            true
            and tt.`from` is not null
            -- Only count C addresses for SACs or custom contract tokens.
            -- Custom contract tokens won't have an asset_type and will contain both C and G addresses
            and (tt.`from` like 'C%' or tt.asset_type = '')
        group by 1, 2, 3
    )

    , merge_to_and_from as (
        select * from token_transfers_to
        union all
        select * from token_transfers_from
    )

    -- Sum the positive and negative balances
    , daily_changes as (
        select
            day
            , account_id
            , contract_id
            , sum(balance) as balance
        from merge_to_and_from
        group by 1, 2, 3
    )

    -- Determine the first day the account_id, contract_id balance should appear
    -- in this table
    , account_date_ranges as (
        select
            account_id
            , contract_id
            , min(day) as start_day
        from daily_changes
        group by 1, 2
    )

    -- Given the first day the account_id, contract_id pair should appear,
    -- create a date spine to maintain a day, account_id, contract_id row
    -- from the first day the account_id, contract_id had a non-zero balance
    -- up until the "batch_end_date" in order to keep a daily balance
    -- from its first day through "batch_end_date" - 1 day (usually the current day)
    , date_spine as (
        select
            adr.account_id
            , adr.contract_id
            , day
        from account_date_ranges as adr
        -- Using batch_end_date - 1 because batch_end_date should not be included in a given run
        , unnest(generate_date_array(adr.start_day, date_sub(date('{{ var("batch_end_date") }}'), interval 1 day))) as day
    )

    -- With the date spine, a daily balance can be calculated by summing all preceeding
    -- daily_change balances for the account_id, contract_id up to the day that is being aggregated.
    , agg as (
        select
            ds.day
            , ds.account_id
            , ds.contract_id
            -- Balances can be negative because custom token contracts may not emit all token value movement events.
            -- This table uses token_transfers to calculate the C address balances
            -- which only has SEP-41 compliant events from custom token contracts.
            , sum(coalesce(dc.balance, 0)) over (
                partition by ds.account_id, ds.contract_id
                order by ds.day
                rows between unbounded preceding and current row
            ) as balance
        from date_spine as ds
        left join daily_changes as dc
            on ds.day = dc.day
            and ds.account_id = dc.account_id
            and ds.contract_id = dc.contract_id
    )

select
    agg.day
    , agg.account_id
    , agg.contract_id
    , a.asset_type
    , a.asset_issuer
    , a.asset_code
    , agg.balance
from agg
left join {{ ref('stg_assets') }} as a
    on agg.contract_id = a.asset_contract_id
