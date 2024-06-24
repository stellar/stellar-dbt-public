[comment]: < Account Signers Current -

{% docs account_signers_current %}

The `account_signers_current` table is a nightly snapshotted table that represents the current status of all account signers associated with an account. The table returns the latest account entry, which is defined as the highest `last_modified_ledger` per account signer on the Stellar Network. Deleted signers are included in the table. For full state history, please use the `account_signers` table.

**The `account_signers_current` table is only updated nightly. Intraday ledger state changes are not captured in the table.**

The `account_signers_current` table may be joined to the `accounts` table in order to find out more information about the originating account. The signers table has a many-to-one relationship with the accounts table, so you should expect multiple records to be returned for each `account_id`.

{% enddocs %}
