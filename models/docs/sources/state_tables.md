[comment]: < Shared Fields in the state tables >

{% docs buying_liabilities %}
The sum of all buy offers owned by this account for XLM only

- Required Field

#### Notes:

The `accounts` table only reports monetary balances for XLM. Any other asset class is reported in the `trust_lines` table. For buy offers, the account must hold the amount of asset to complete the transaction
{% enddocs %}

{% docs selling_liabilities %}
The sum of all sell offers owned by this account for XLM only

- Required Field

#### Notes:

The `accounts` table only reports monetary balances for XLM. Any other asset class is reported in the `trust_lines` table.
{% enddocs %}

{% docs flags_trust_lines %}
Denotes the enabling and disabling of certain asset issuer privileges.

- Required Field

#### Notes:

Flags are set on the issuer accounts for an asset. When user accounts trust an asset, the flags applied to the asset originate from this account. Depending on the state table, flags can have various meanings.

#### `trust_lines`:

| Flag    | Meaning                      |
|---------|------------------------------|
| 0       | None, Default                      |
| 1       | Authorized (issuer has authorized account to perform transaction with its credit)        |
| 2       | Authorized to Maintain Liabilities (issuer has authorized account to maintain and reduce liabilities for its credit)        |
| 4       | Clawback Enabled (issuer has specified that it may clawback its credit, including claimable balances)     |

{% enddocs %}

{% docs flags_accounts_balances %}
Denotes the enabling and disabling of certain asset issuer privileges.

- Required Field

#### Notes:

Flags are set on the issuer accounts for an asset. When user accounts trust an asset, the flags applied to the asset originate from this account. Depending on the state table, flags can have various meanings.

#### `accounts` and `claimable_balances`:

| Flag    | Meaning                |
|----------|----------------------------|
| 0        | None - Default             |
| 1        | Auth Required (all trustlines by default are untrusted and require manual trust established)            |
| 2        | Auth Revocable (allows trustlines to be revoked if account no longer trusts asset) |
| 4        | Auth Immutable (all auth flags are read only when set)         |
| 8        | Auth Clawback Enabled (asset can be clawed back from the user) |

{% enddocs %}

{% docs flags_offers %}
Denotes the enabling and disabling of certain asset issuer privileges.

- Required Field

#### Notes:

Flags are set on the issuer accounts for an asset. When user accounts trust an asset, the flags applied to the asset originate from this account. Depending on the state table, flags can have various meanings.

#### `offers`:

| Flag | Meaning                                                                                |
| ---- | -------------------------------------------------------------------------------------- |
| 0    | Default                                                                                |
| 1    | Passive (offer with this flag will not act on and take a reverse offer of equal price) |

{% enddocs %}
