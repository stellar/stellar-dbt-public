{% set meta_config = {
    "unique_key": ["day", "account_id", "contract_id"],
    "event_time": "day",
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
    -- Contract tokens that were not emitting usable SEP-41 events, so their balances over
    -- that period have to come from contract storage. `events_start_from` is the day the
    -- contract started emitting reliably; null means it still is not.
    -- Defaults match the soroban-token-sdk layout: a balance entry keyed
    -- ScVec[ScSymbol("Balance"), ScAddress] with an i128 value.
    storage_sources as (
        select
            contract_id
            , effective_from
            , events_start_from
            , coalesce(nullif(balance_key_symbol, ''), 'Balance') as balance_key_symbol
            , coalesce(holder_key_index, 1) as holder_key_index
            , coalesce(nullif(amount_value_type, ''), 'i128') as amount_value_type
            , decimals
        from {{ ref('contract_token_balance_sources') }}
    )

    -- Storage holds balance *levels*, not deltas. Each SCD-2 version of a Balance entry
    -- is held flat across the days it was live; a version whose interval opens and closes
    -- on the same day contributes no days, which is what resolves intra-day churn to the
    -- end-of-day state. Levels drive balances up to the handover day, and the level
    -- standing on that day is converted into the one delta the event stream is missing.
    , storage_balance_versions as (
        select
            cd.contract_id
            , json_value(cd.key_decoded['vec'][src.holder_key_index]['address']) as account_id
            , cast(json_value(cd.val_decoded[src.amount_value_type]) as bignumeric) as balance_raw
            , greatest(date(cd.valid_from), src.effective_from) as start_day
            -- valid_to is exclusive; an open interval runs to the end of the batch window.
            -- Storage stops driving balances on the handover day: from then on the event
            -- stream carries them, opened at the level captured in storage_opening_balances.
            , least(
                coalesce(date(cd.valid_to), date('{{ var("batch_end_date") }}'))
                , coalesce(src.events_start_from, date('{{ var("batch_end_date") }}'))
            ) as end_day
        from {{ ref('contract_data_snapshot') }} as cd
        inner join storage_sources as src
            on cd.contract_id = src.contract_id
        where
            true
            -- An archived or removed entry closes its interval, so the holder simply stops
            -- producing days rather than being carried forward at a stale balance.
            and cd.deleted = false
            and json_value(cd.key_decoded['vec'][0]['symbol']) = src.balance_key_symbol
    )

    -- The storage level still standing on the day before events take over, emitted as a
    -- single synthetic delta on the handover day. This is the opening balance the event
    -- stream cannot supply on its own: the contracts were fixed to emit events going
    -- forward, not retroactively, so every token minted before the fix appears in no
    -- event at all. Feeding it through daily_changes lets the existing cumulative sum
    -- carry it forward with real event deltas landing on top -- no separate splice.
    , storage_opening_balances as (
        select
            src.events_start_from as day
            , sbv.account_id
            , sbv.contract_id
            -- Decimals come from the seed, where they were read off the contract once and
            -- verified. These contracts do not follow the SEP-41 storage convention, so
            -- int_asset_metadata cannot reliably parse them and would silently fall back
            -- to 10^-7.
            , cast(sum(
                sbv.balance_raw / cast(pow(10, src.decimals) as bignumeric)
            ) as float64) as balance
        from storage_balance_versions as sbv
        inner join storage_sources as src
            on sbv.contract_id = src.contract_id
        where
            src.events_start_from is not null
            -- The version live at the end of the day before the handover. end_day is
            -- already clamped to events_start_from, so ">=" selects exactly the versions
            -- that were still open when storage stopped driving.
            and sbv.start_day < src.events_start_from
            and sbv.end_day >= src.events_start_from
            and sbv.account_id is not null
        group by 1, 2, 3
    )

    -- Amounts should be added when assets are sent to the account.
    -- `amount` arrives pre-scaled (10^-decimal applied) from int_token_transfer_enrichment.
    , token_transfers_to as (
        select
            date(tt.closed_at) as day
            , tt.to as account_id
            , tt.contract_id
            , sum(tt.amount) as balance
        from {{ ref('int_token_transfer_enrichment') }} as tt
        where
            true
            and tt.to is not null
            -- Only count C addresses for SACs or custom contract tokens.
            -- Custom contract tokens won't have an asset_type and will contain both C and G addresses
            and (tt.to like 'C%' or tt.asset_type = '')
            {{ exclude_pre_event_contract_transfers('tt') }}
        group by 1, 2, 3
    )

    -- Amounts should be subtracted when assets are sent from the account.
    , token_transfers_from as (
        select
            date(tt.closed_at) as day
            , tt.`from` as account_id
            , tt.contract_id
            , -sum(tt.amount) as balance
        from {{ ref('int_token_transfer_enrichment') }} as tt
        where
            true
            and tt.`from` is not null
            -- Only count C addresses for SACs or custom contract tokens.
            -- Custom contract tokens won't have an asset_type and will contain both C and G addresses
            and (tt.`from` like 'C%' or tt.asset_type = '')
            {{ exclude_pre_event_contract_transfers('tt') }}
        group by 1, 2, 3
    )

    , merge_to_and_from as (
        select * from token_transfers_to
        union all
        select * from token_transfers_from
        union all
        select day, account_id, contract_id, balance from storage_opening_balances
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

    , storage_balances as (
        select
            day
            , sbv.account_id
            , sbv.contract_id
            -- Scale in bignumeric and cast once, so a 15+ significant-digit raw balance
            -- does not lose precision before it reaches the float64 output column.
            -- Decimals come from the seed, where they were read off the contract once and
            -- verified. These contracts do not follow the SEP-41 storage convention, so
            -- int_asset_metadata cannot reliably parse them and would silently fall back
            -- to 10^-7.
            , cast(sum(
                sbv.balance_raw / cast(pow(10, src.decimals) as bignumeric)
            ) as float64) as balance
        from storage_balance_versions as sbv
        inner join storage_sources as src
            on sbv.contract_id = src.contract_id
        cross join unnest(generate_date_array(sbv.start_day, date_sub(sbv.end_day, interval 1 day))) as day
        where sbv.account_id is not null
        group by 1, 2, 3
    )

    , all_balances as (
        select day, account_id, contract_id, balance from agg
        union all
        select day, account_id, contract_id, balance from storage_balances
    )

select
    all_balances.day
    , all_balances.account_id
    , all_balances.contract_id
    , a.asset_type
    , a.asset_issuer
    , a.asset_code
    , all_balances.balance
from all_balances
left join {{ ref('int_asset_metadata') }} as a
    on all_balances.contract_id = a.contract_id
