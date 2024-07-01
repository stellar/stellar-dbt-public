[comment]: < Accounts -

{% docs accounts %}
The accounts table stores detailed information for a given account, including current account status, preconditions for transaction authorization, security settings and account balance. The balance reported in the accounts table reflects the account’s XLM balance only. All other asset balances are reported in the 'trust_lines' table.
Any changes to the account, whether it is an account settings change, balance increase/decrease or sponsorship change will result in an increase to the account sequence_number and last_modified_ledger. The sequence_number is incremented with each operation applied to an account so that order is preserved during account mutation.
{% enddocs %}

{% docs account_id %}
The address of the account. The address is the account's public key encoded in base32. All account addresses start with a 'G'.

- Natural Key
- Cluster Field
- Required Field
  {% enddocs %}

{% docs balance %}
The number of units of XLM held by the account

- Required Field

#### Notes:

The `accounts` table only reports monetary balances for XLM. Any other asset class is reported in the `trust_lines` table.
{% enddocs %}

{% docs sequence_number %}
The account's current sequence number. The sequence number controls operations applied to an account. Operations must submit a unique sequence number that is incremented by 1 in order to apply the operation to the account so that account changes will not collide within a ledger.

- Natural Key
- Required Field
  {% enddocs %}

{% docs num_subentries %}
The total number of ledger entries connected to this account. Ledger entries include: trustlines, offers, signers, and data entries. (Claimable balances are counted under sponsoring entries, not subentries). Any newly created trustline, offer, signer or data entry will increase the number of subentries by 1. Accounts may have up to 1,000 subentries

- Required Field

#### Notes:

Each entry on a ledger takes up space, which is expensive to store on the blockchain. For each entry, an account is required to hold a [minimum XLM balance](https://developers.stellar.org/docs/fundamentals-and-concepts/lumens#minimum-balance). The reserve is calculated by (2 + num_subentries - num_sponsoring + num_sponsored) \* 0.5XLM
{% enddocs %}

{% docs inflation_destination %}
Deprecated: The account address to receive an inflation payment when they are disbursed on the network.

#### Notes:

Inflation was discontinued in 2019 by validator vote.
{% enddocs %}

{% docs home_domain %}
The domain that hosts this account's stellar.toml file.

- Required Field

#### Notes:

Only applies to asset issuer accounts. The stellar.toml file contains metadata about the asset issuer which helps identify who the issuer is and instills trust in the asset
{% enddocs %}

{% docs master_weight %}
The weight of the master key, which is the private key for this account. If a master key is '0', the account is locked and cannot be used.

- Required Field

| Accepted Values        |
| ---------------------- |
| Integers from 1 to 255 |

{% enddocs %}

{% docs threshold_low %}
The sum of the weight of all signatures that sign a transaction for the low threshold operation. The weight must exceed the set threshold for the operation to succeed.

- Required Field

#### Notes:

Each operation falls under a specific threshold category: low, medium or high. Thresholds define the level of privilege an operation needs in order to succeed (this is a security measure)

| Security | Operations                                                                   |
| -------- | ---------------------------------------------------------------------------- |
| Low      | Allow Trust, Set Trust Line Flags, Bump Sequence and Claim Claimable Balance |
| Medium   | Everything Else                                                              |
| High     | Account Merge, Set Options                                                   |

{% enddocs %}

{% docs threshold_medium %}
The sum of the weight of all signatures that sign a transaction for the medium threshold operation. The weight must exceed the set threshold for the operation to succeed.

- Required Field

#### Notes:

Each operation falls under a specific threshold category: low, medium or high. Thresholds define the level of privilege an operation needs in order to succeed (this is a security measure)

| Security | Operations                                                                   |
| -------- | ---------------------------------------------------------------------------- |
| Low      | Allow Trust, Set Trust Line Flags, Bump Sequence and Claim Claimable Balance |
| Medium   | Everything Else                                                              |
| High     | Account Merge, Set Options                                                   |

{% enddocs %}

{% docs threshold_high %}
The sum of the weight of all signatures that sign a transaction for the high threshold operation. The weight must exceed the set threshold for the operation to succeed.

- Required Field

#### Notes:

Each operation falls under a specific threshold category: low, medium or high. Thresholds define the level of privilege an operation needs in order to succeed (this is a security measure)

| Security | Operations                                                                   |
| -------- | ---------------------------------------------------------------------------- |
| Low      | Allow Trust, Set Trust Line Flags, Bump Sequence and Claim Claimable Balance |
| Medium   | Everything Else                                                              |
| High     | Account Merge, Set Options                                                   |

{% enddocs %}

{% docs num_sponsored %}
The number of reserves sponsored for this account (meaning another account is paying for the minimum balance). Sponsored entries do not incur any reserve requirement on the account that owns the entry.

#### Notes:

Defaults to 0
Accounts, offers, trustlines, data and signers can be optionally sponsored. Claimable Balances must be sponsored. See more information on sponsorship [here](https://developers.stellar.org/docs/encyclopedia/sponsored-reserves).
{% enddocs %}

{% docs num_sponsoring %}
The number of reserves sponsored by this account. Entries sponsored by this account incur a reserve requirement.

#### Notes:

Defaults to 0
Accounts, offers, trustlines, data and signers can be optionally sponsored. Claimable Balances must be sponsored. See more information on sponsorship [here](https://developers.stellar.org/docs/encyclopedia/sponsored-reserves).
{% enddocs %}

{% docs sequence_ledger %}
The unsigned 32-bit ledger number of the sequence number's age.

#### Notes:

Reflects the last time an account touched its sequence number. Note that even if the Bump Sequence operation has no effect, eg it does not increase the sequence number, it still counts as a "touch"
{% enddocs %}

{% docs sequence_time %}
The UNIX timestamp of the sequence number's age.

#### Notes:

Reflects the last time an account touched its sequence number. Note that even if the Bump Sequence operation has no effect, eg it does not increase the sequence number, it still counts as a "touch"
{% enddocs %}
