-- Every contract declared in contract_token_balance_sources must actually yield balances.
--
-- The parser columns (balance_key_symbol, holder_key_index, amount_value_type) address
-- contract storage by shape. Get any of them wrong for a new contract and the JSON
-- navigation returns null rather than raising: the contract is already excluded from the
-- event path, so the asset silently drops to zero supply instead of being fixed. This
-- test is the tripwire for that -- it fails on a declared contract that produced no
-- positive balance on the most recent day of the model.

with
    active_sources as (
        select contract_id
        from {{ ref('contract_token_balance_sources') }}
        where
            effective_from < date('{{ var("batch_end_date") }}')
            and (effective_to is null or effective_to >= date('{{ var("batch_end_date") }}'))
    )

    , last_day as (
        select max(day) as day
        from {{ ref('int_account_balances__contracts') }}
    )

    , balances_on_last_day as (
        select distinct iabc.contract_id
        from {{ ref('int_account_balances__contracts') }} as iabc
        inner join last_day as ld
            on iabc.day = ld.day
        where iabc.balance > 0
    )

select src.contract_id
from active_sources as src
left join balances_on_last_day as b
    on src.contract_id = b.contract_id
where b.contract_id is null
