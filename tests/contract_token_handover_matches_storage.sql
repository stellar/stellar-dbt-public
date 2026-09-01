-- After the handover, balances for these contracts come from their own event stream --
-- and every contract in this seed is there because it demonstrably failed to emit usable
-- events at least once. Contract storage keeps recording Balance entries either way, so it
-- remains a free, independent oracle for exactly the thing we have started trusting.
--
-- This compares the two on the most recent day of the model, per holder. It catches:
--   * events_start_from set too early -- to the upgrade day rather than the day after, or
--     before balances existed at all -- which silently loses movement the event stream
--     never reported
--   * a contract that was "fixed" but still emits incompletely
--
-- It deliberately does NOT cover a mis-set parser column. Both sides of this comparison
-- read storage through the same seed config, so a wrong holder_key_index or
-- amount_value_type makes them agree on the same wrong answer. That failure mode empties
-- the contract instead, and is caught by
-- contract_token_balance_sources_produce_balances.
--
-- Only contracts whose events_start_from has passed are compared; one still driven by
-- storage costs nothing here.

with
    handed_over as (
        select
            contract_id
            , coalesce(nullif(balance_key_symbol, ''), 'Balance') as balance_key_symbol
            , coalesce(holder_key_index, 1) as holder_key_index
            , coalesce(nullif(amount_value_type, ''), 'i128') as amount_value_type
            , decimals
        from {{ ref('contract_token_balance_sources') }}
        where
            events_start_from is not null
            and events_start_from < date('{{ var("batch_end_date") }}')
    )

    , as_of as (
        select max(day) as day
        from {{ ref('int_account_balances__contracts') }}
    )

    , storage_level as (
        select
            cd.contract_id
            , json_value(cd.key_decoded['vec'][h.holder_key_index]['address']) as account_id
            , cast(sum(
                cast(json_value(cd.val_decoded[h.amount_value_type]) as bignumeric)
                / cast(pow(10, h.decimals) as bignumeric)
            ) as float64) as balance
        from {{ ref('contract_data_snapshot') }} as cd
        inner join handed_over as h
            on cd.contract_id = h.contract_id
        cross join as_of
        where
            cd.deleted = false
            and json_value(cd.key_decoded['vec'][0]['symbol']) = h.balance_key_symbol
            and date(cd.valid_from) <= as_of.day
            and (cd.valid_to is null or date(cd.valid_to) > as_of.day)
        group by 1, 2
    )

    , event_derived as (
        select
            iabc.contract_id
            , iabc.account_id
            , iabc.balance
        from {{ ref('int_account_balances__contracts') }} as iabc
        inner join as_of
            on iabc.day = as_of.day
        inner join handed_over as h
            on iabc.contract_id = h.contract_id
    )

select
    coalesce(e.contract_id, s.contract_id) as contract_id
    , coalesce(e.account_id, s.account_id) as account_id
    , e.balance as event_derived_balance
    , s.balance as storage_balance
from event_derived as e
full outer join storage_level as s
    on e.contract_id = s.contract_id
    and e.account_id = s.account_id
where
    -- Relative tolerance absorbs float64 accumulation over a long cumulative sum; a real
    -- missed event is orders of magnitude larger than this.
    abs(coalesce(e.balance, 0) - coalesce(s.balance, 0))
        > greatest(1e-6, 1e-9 * abs(coalesce(s.balance, 0)))
