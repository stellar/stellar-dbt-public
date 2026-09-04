{#
    Filters out token transfer events that predate the day a contract's events became
    trustworthy (see the contract_token_balance_sources seed).

    A contract listed in the seed was emitting no usable SEP-41 events for some period.
    Its balances over that period come from contract storage instead, so replaying its
    events there as well would double-count. `events_start_from` is the day the contract
    started emitting reliably; before that day its events are ignored, and when it is null
    the contract is not emitting yet and every event is ignored.

    The handover is safe only because storage also supplies the opening balance on the
    cutover day -- see storage_opening_balances in int_account_balances__contracts. Without
    it the cumulative sum would restart from zero and understate every holder by whatever
    they held when the contract was fixed.

    `alias` is the table alias of the token-transfer relation being filtered.
#}
{% macro exclude_pre_event_contract_transfers(alias) %}
    and not exists (
        select 1
        from {{ ref('contract_token_balance_sources') }} as ctbs
        where
            ctbs.contract_id = {{ alias }}.contract_id
            and (
                ctbs.events_start_from is null
                or date({{ alias }}.closed_at) < ctbs.events_start_from
            )
    )
{% endmacro %}
