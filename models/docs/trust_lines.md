[comment]: < Trust_lines -

{% docs trust_lines %}
Trustlines track authorized and deleted lines of trust between an account and assets. This table can be viewed as a subentry to an account because all trustlines must be associated with a single account. The trust line also tracks the balance of the asset held by the account and any buying or selling liabilities on the orderbook for a given account and asset. You do not have to hold a balance of an asset to trust the asset. 
{% enddocs %}

{% docs ledger_key %}
The unique ledger key when the trust line state last changed.

- Natural Key
- Required Field
{% enddocs %}

{% docs trust_account_id %}
The account address 

- Natural Key
- Required Field
{% enddocs %}

{% docs trust_asset_type %}
The identifier for type of asset code, can be a alphanumeric with 4 characters, 12 characters or the native asset to the network, XLM.

- Natural Key
- Required Field
{% enddocs %}

{% docs trust_asset_issuer %}
The 4 or 12 character code representation of the asset held by this account

- Natural Key
{% enddocs %}

{% docs trust_asset_code %}
The account address of the original asset issuer that created the asset held by this account

- Natural Key
{% enddocs %}

{% docs trust_liquidity_pool_id %}
If the asset held is part of a liquidity pool share, the unique pool id from which the asset balance originates.

- Natural Key
{% enddocs %}

{% docs trust_balance %}
The number of units of an asset held by this account.

- Required Field
{% enddocs %}

{% docs trust_line_limits %}
The maximum amount of this asset that this account is willing to accept. The limit is specified when opening a trust line.

- Required Field
{% enddocs %}

{% docs trust_buying_liabilities %}
The sum of all buy offers owned by this account for non-native assets.

- Required Field
{% enddocs %}

{% docs trust_selling_liabilities %}
The sum of all sell offers owned by this account for non-native assets.

- Required Field
{% enddocs %}

{% docs trust_flags %}
Denotes the enabling/disabling of certain asset issuer privileges.

#### Notes:
Flags are set on the issuer accounts for an asset. When user accounts trust an asset, the flags applied to the asset originate from this account.

| Flag    | Meaning                      |
|---------|------------------------------|
| 0       | None, Default                      |
| 1       | Authorized (issuer has authorized account to perform transaction with its credit)        |
| 2       | Authorized to Maintain Liabilities (issuer has authorized account to maintain and reduce liabilities for its credit)        |
| 4       | Clawback Enabled (issuer has specified that it may clawback its credit, including claimable balances)     |
{% enddocs %}

{% docs trust_last_modified_ledger %}
The ledger sequence number when the ledger entry (this unique signer for the account) was modified. Deletions do not count as a modification and will report the prior modification sequence number.

- Natural Key
- Cluster Field
- Required Field
{% enddocs %}

{% docs trust_ledger_entry_change %}
Code that describes the ledger entry change type that was applied to the ledger entry.

- Required Field

#### Notes:
Valid entry change types are 0, 1, and 2 for ledger entries of type `trust_lines`. 

| Value    | Description                |
|----------|----------------------------|
| 0        | Ledger Entry Created       |
| 2        | Ledger Entry Deleted       |
{% enddocs %}

{% docs trust_deleted %}
Indicates whether the ledger entry (trust line) has been deleted or not. Once an entry is deleted, it cannot be recovered.

- Required Field
{% enddocs %}

{% docs trust_sponsor %}
The account address that is sponsoring the base reserves for the trust line.
{% enddocs %}