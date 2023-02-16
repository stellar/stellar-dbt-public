[comment]: < Claimable Balances -

{% docs claimable_balances %}


{% enddocs %}

{% docs balance_id %}
A unique identifier for this claimable balance. The Balance id is a compilation of `Balance Type` + `SHA-256 hash history_operation_id`

- Natural Key
- Cluster Field
- Required Field

#### Notes:
The Balance Type is fixed at V0, `00000000`. If there is a protocol change that materially impacts the mechanics of claimable balances, the balance type would update to V1.
{% enddocs %}

{% docs claimants %}
The list of entries which are eligible to claim the balance and preconditions that must be fulfilled to claim.

- Required Field

#### Notes:
Multiple accounts can be specified in the claimants record, including the account of the balance creator.
{% enddocs %}

{% docs claimants_destination %}
The account id who can claim the balance.

- Required Field
{% enddocs %}

{% docs claimants_predicate %}
The condition which must be satisfied so the destination can claim the balance. The predicate can include logical rules using AND, OR and NOT logic.

- Required Field
{% enddocs %}

{% docs claimants_predicate_unconditional %}
If true it means this clause of the condition is always satisfied.

#### Notes:
When the predicate is only unconditional = true, it means that the balance can be claimed under any conditions
{% enddocs %}

{% docs claimants_predicate_abs_before %}
Deadline for when the balance must be claimed. If a balance is claimed before the date then the clause of the condition is satisfied. 
{% enddocs %}

{% docs claimants_predicate_rel_before %}
A relative deadline for when the claimable balance can be claimed. The value represents the number of seconds since the close time of the ledger which created the claimable balance

#### Notes:
This condition is useful when creating a timebounds based on creation conditions. If the creator wanted a balance only claimable one week after creation, this condition would satisfy that rule.
{% enddocs %}

{% docs claimants_predicate_abs_before_epoch %}
A UNIX epoch value in seconds representing the same deadline date as abs_before.
{% enddocs %}

{% docs cl_asset_type %}
The identifier for type of asset code, can be a alphanumeric with 4 characters, 12 characters or the native asset to the network, XLM.

- Required Field
{% enddocs %}

{% docs cl_asset_code %}
The 4 or 12 character code representation of the asset on the network.
{% enddocs %}

{% docs cl_asset_issuer %}
The account address of the original asset issuer that created the asset.
{% enddocs %}

{% docs cl_asset_amount %}
The amount of the asset that can be claimed.

- Required Field
{% enddocs %}

{% docs cl_sponsor %}
The account address of the sponsor who is paying the reserves for this account.

#### Notes:
Sponsors of claimable balances are the creators of the balance.
{% enddocs %}

{% docs cl_flags %}
Denotes the enabling and disabling of certain balance issuer privileges

- Required Field

#### Notes:
Flags are set by the claimable balance accounts for an asset. When user accounts claim a balance, the flags applied to the asset originate from this account

| Value    | Description                |
|----------|----------------------------|
| 0        | None - Default             |
| 1        | Auth Required (all trustlines by default are untrusted and require manual trust established)            |
| 2        | Auth Revocable (allows trustlines to be revoked if account no longer trusts asset) |
| 4        | Auth Immutable (all auth flags are read only when set)         |
| 8        | Auth Clawback Enabled (asset can be clawed back from the user) |
{% enddocs %}

{% docs cl_last_modified_ledger %}
The ledger sequence number when the ledger entry (this unique signer for the account) was modified. Deletions do not count as a modification and will report the prior modification sequence number

- Natural Key
- Cluster Field
- Required Field
{% enddocs %}

{% docs cl_ledger_entry_change %}
Code that describes the ledger entry change type that was applied to the ledger entry. 

- Required Field

#### Notes:
Valid entry change types are 0 and 2 for ledger entries of type `claimable_balances`. Once created, a balance cannot be updated.

| Value    | Description                |
|----------|----------------------------|
| 0        | Ledger Entry Created       |
| 2        | Ledger Entry Deleted       |
{% enddocs %}

{% docs cl_deleted %}
Indicates whether the ledger entry (balance id) has been deleted or not. Once an entry is deleted, it cannot be recovered.

- Required Field
{% enddocs %}