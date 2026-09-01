{#
    Filters out contract tokens whose balances are read from contract storage rather than
    from SEP-41 token transfer events (see the contract_token_balance_sources seed).

    A contract is either event-sourced or storage-sourced for its whole life; the two are
    never spliced together. The event path derives balances by cumulatively summing
    transfer deltas, so it has no opening balance to start from -- a contract sourced from
    storage up to some cutover and from events after it would be understated on the event
    side by exactly the balance that existed at the cutover.

    `alias` is the table alias of the token-transfer relation being filtered.
#}
{% macro exclude_storage_sourced_contracts(alias) %}
    and {{ alias }}.contract_id not in (
        select contract_id from {{ ref('contract_token_balance_sources') }}
    )
{% endmacro %}
