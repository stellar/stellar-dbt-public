-- Every contract declared in contract_token_balance_sources must actually yield balances.
--
-- The parser columns (balance_key_symbol, holder_key_index, amount_value_type) address
-- contract storage by shape. Get any of them wrong for a new contract and the JSON
-- navigation returns null rather than raising: the contract's own pre-handover events are
-- already suppressed, so the asset silently drops to zero supply instead of being fixed.
-- After the handover the same mistake corrupts the opening balance instead, which is just
-- as silent. This test is the tripwire for both -- it fails on a declared contract that
-- has never produced a positive balance on any day.
--
-- Any day rather than the latest: a fully redeemed token legitimately sits at zero, and its
-- seed row has to stay so a full rebuild can still open the event stream, whereas a mis-set
-- parser produces nothing at all because the model rebuilds from scratch. After handover a
-- mis-set parser leaves event-derived balances with no storage counterpart, which
-- contract_token_handover_matches_storage reports.

with
    active_sources as (
        select contract_id
        from {{ ref('contract_token_balance_sources') }}
        where effective_from < date('{{ var("batch_end_date") }}')
    )

    , contracts_with_balances as (
        select distinct contract_id
        from {{ ref('int_account_balances__contracts') }}
        where balance > 0
    )

select src.contract_id
from active_sources as src
left join contracts_with_balances as b
    on src.contract_id = b.contract_id
where b.contract_id is null
