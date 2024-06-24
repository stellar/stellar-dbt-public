[comment]: < Trust Lines Current -

{% docs trust_lines_current %}

The `trust_lines_current` table is a nightly snapshotted table that represents the current state of account trustlines. The table returns the latest trustline entry, per account, which is defined as the highest `last_modified_ledger` per trustline/account on the Stellar Network. Deleted trust lines are included in the table. For full state history, please use the `trust_lines` table.

**The `trust_lines_current` table is only updated nightly. Intraday ledger state changes are not captured in the table.**

As a reminder, trustline ledger entries store detailed information for assets trusted by a given account. The balance reported in the trustlines table reflects the account’s trusted asset balances, `XLM` balance is reported in the `accounts` table.

{% enddocs %}
