[comment]: < Accounts Current -

{% docs accounts_current %}

The `accounts_current` table is a nightly snapshotted table that represents the current state of account ledger entries. The table returns the latest account entry, which is defined as the highest `last_modified_ledger` per account on the Stellar Network. Deleted accounts are included in the table. For full state history, please use the `accounts` table.

**The `accounts_current` table is only updated nightly. Intraday ledger state changes are not captured in the table.**

As a reminder, account ledger entries store detailed information for a given account, including current account status, preconditions for transaction authorization, security settings and account balance. The balance reported in the accounts table reflects the account’s XLM balance only. All other asset balances are reported in the `trust_lines` table.

{% enddocs %}
