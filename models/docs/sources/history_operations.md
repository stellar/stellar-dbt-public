[comment]: < History Operations -

{% docs history_operations %}
The history operations table contains the lowest granularity of data avaiable to the network. It contains all details regarding operations that were executed as part of a transaction set. Be careful - the table contains both failed and successful operations (history_transactions contains the succesful indicator). The details record will return varying information about an operation according to the operation type.
{% enddocs %}

{% docs operation_id %}
Unique identifier for an operation.

- Primary Key
- Natural Key
- Cluster Field
- Required Field

#### Notes:

The operation id is the transaction id + order number
{% enddocs %}

{% docs source_account %}
The account address that originates the operation

- Cluster Field
- Required Field

#### Notes:

Defaults to ''
{% enddocs %}

{% docs source_account_muxed %}
If an account is multiplexed (muxed), the virtual account address that originates the operation
{% enddocs %}

{% docs op_transaction_id %}
The transaction identifier in which the operation executed. There can be up to 100 operations in a given transaction

- Cluster Field
- Required Field
  {% enddocs %}

{% docs type %}
The number indicating which type of operation this operation executes

- Required Field
  {% enddocs %}

{% docs type_string %}
The type of operation this operation executes

- Required Field
  {% enddocs %}

{% docs operation_result_code %}
The result code returned when the Stellar Network applies an operation. This code is helpful for understanding failed transactions.
{% enddocs %}

{% docs operation_trace_code %}
The trace code returned when an operation is applied to the Stellar Network. This code is helpful for understanding failure types.
{% enddocs %}

{% docs details %}
Record that contains details based on the type of operation executed. Each operation will return its own relevant details, with the rest of the details as null
{% enddocs %}

{% docs details_account %}
The amount of sold asset that was moved from the seller account to the buyer account, reported in terms of the sold amount

### Only exists for the following operations:

| Type | Operation      |
| ---- | -------------- |
| 0    | Create Account |
| 8    | Account Merge  |

{% enddocs %}

{% docs details_account_muxed %}
The virtual address of the account if the account is multiplexed

### Only exists for the following operations:

| Type | Operation     |
| ---- | ------------- |
| 8    | Account Merge |

{% enddocs %}

{% docs details_account_muxed_id %}
Integer representation of the virtual address of the account if the account is multiplexed.

### Only exists for the following operations:

| Type | Operation     |
| ---- | ------------- |
| 8    | Account Merge |

{% enddocs %}

{% docs details_account_id %}
The address of the account which is no longer sponsored

### Only exists for the following operations:

| Type | Operation          |
| ---- | ------------------ |
| 18   | Revoke Sponsorship |

{% enddocs %}

{% docs details_amount %}
Float representation of the amount of an asset sent/offered/etc

### Only exists for the following operations:

| Type | Operation                   |
| ---- | --------------------------- |
| 1    | Payment                     |
| 2    | Path Payment Strict Receive |
| 3    | Manage Sell Offer           |
| 4    | Create Passive Sell Offer   |
| 12   | Manage Buy Offer            |
| 13   | Path Payment Strict Send    |
| 14   | Create Claimable Balance    |
| 19   | Clawback                    |

{% enddocs %}

{% docs details_asset %}
The asset available to be claimed in the form of "asset_code:issuing_address". If the claimable balance is in XLM, it is reported as "native"

### Only exists for the following operations:

| Type | Operation                |
| ---- | ------------------------ |
| 14   | Create Claimable Balance |

{% enddocs %}

{% docs details_asset_code %}
The 4 or 12 character code representation of the asset on the network

### Only exists for the following operations:

| Type | Operation                   |
| ---- | --------------------------- |
| 1    | Payment                     |
| 2    | Path Payment Strict Receive |
| 6    | Change Trust                |
| 7    | Allow Trust                 |
| 13   | Path Payment Strict Send    |
| 19   | Clawback                    |
| 21   | Set Trustline Flags         |

#### Notes:

Asset codes have no guarantees of uniqueness. The combination of asset code, issuer and type represents a distinct asset
{% enddocs %}

{% docs details_asset_issuer %}
The account address of the original asset issuer that created the asset

### Only exists for the following operations:

| Type | Operation                   |
| ---- | --------------------------- |
| 1    | Payment                     |
| 2    | Path Payment Strict Receive |
| 6    | Change Trust                |
| 7    | Allow Trust                 |
| 13   | Path Payment Strict Send    |
| 19   | Clawback                    |
| 21   | Set Trustline Flags         |

{% enddocs %}

{% docs details_asset_type %}
The identifier for type of asset code, can be a alphanumeric with 4 characters, 12 characters or the native asset to the network, XLM.

### Only exists for the following operations:

| Type | Operation                   |
| ---- | --------------------------- |
| 1    | Payment                     |
| 2    | Path Payment Strict Receive |
| 6    | Change Trust                |
| 7    | Allow Trust                 |
| 13   | Path Payment Strict Send    |
| 19   | Clawback                    |
| 21   | Set Trustline Flags         |

#### Notes:

XLM is the native asset to the network. XLM has no asset code or issuer representation and will instead be displayed with an asset type of 'native'
{% enddocs %}

{% docs details_authorize %}
Indicates whether the trustline is authorized. 0 is if the account is not authorized to transact with the asset in any way. 1 if the account is authorized to transact with the asset. 2 if the account is authorized to maintain orders, but not to perform other transactions.

### Only exists for the following operations:

| Type | Operation   |
| ---- | ----------- |
| 7    | Allow Trust |

{% enddocs %}

{% docs details_balance_id %}
The balance id of the claimable balance which is claimed or no longer sponsored

### Only exists for the following operations:

| Type | Operation                  |
| ---- | -------------------------- |
| 15   | Claim Claimable Balance    |
| 20   | Clawback Claimable Balance |

{% enddocs %}

{% docs details_buying_asset_code %}
The 4 or 12 character code representation of the asset that is either bought or offered to buy in a trade

### Only exists for the following operations:

| Type | Operation                 |
| ---- | ------------------------- |
| 3    | Manage Sell Offer         |
| 4    | Create Passive Sell Offer |
| 12   | Manage Buy Offer          |

{% enddocs %}

{% docs details_buying_asset_issuer %}
The account address of the original asset issuer that created the asset bought or offered to buy

### Only exists for the following operations:

| Type | Operation                 |
| ---- | ------------------------- |
| 3    | Manage Sell Offer         |
| 4    | Create Passive Sell Offer |
| 12   | Manage Buy Offer          |

{% enddocs %}

{% docs details_buying_asset_type %}
The identifier for type of asset code, can be a alphanumeric with 4 characters, 12 characters or the native asset to the network, XLM.

### Only exists for the following operations:

| Type | Operation                 |
| ---- | ------------------------- |
| 3    | Manage Sell Offer         |
| 4    | Create Passive Sell Offer |
| 12   | Manage Buy Offer          |

#### Notes:

XLM is the native asset to the network. XLM has no asset code or issuer representation and will instead be displayed with an asset type of 'native'
{% enddocs %}

{% docs details_claimable_balance_id %}
The balance id of the claimable balance which is no longer sponsored

### Only exists for the following operations:

| Type | Operation          |
| ---- | ------------------ |
| 18   | Revoke Sponsorship |

{% enddocs %}

{% docs details_claimant %}
The account address of the account which claimed the claimable balance

### Only exists for the following operations:

| Type | Operation               |
| ---- | ----------------------- |
| 15   | Claim Claimable Balance |

{% enddocs %}

{% docs details_claimant_muxed %}
If the account is multiplexed, the virtual address of the account which claimed the claimable balance

### Only exists for the following operations:

| Type | Operation               |
| ---- | ----------------------- |
| 15   | Claim Claimable Balance |

{% enddocs %}

{% docs details_claimant_muxed_id %}
If the account is multiplexed, an integer representation of the muxed account which claimed the balance

### Only exists for the following operations:

| Type | Operation               |
| ---- | ----------------------- |
| 15   | Claim Claimable Balance |

{% enddocs %}

{% docs details_claimants %}
An unstructured field that lists account addresses eligible to claim a balance and the conditions which must be satisfied to claim the balance (typically time bound conditions)

### Only exists for the following operations:

| Type | Operation                |
| ---- | ------------------------ |
| 14   | Create Claimable Balance |

{% enddocs %}

{% docs details_data_account_id %}
The account address of the account whose data entry is no longer sponsored

### Only exists for the following operations:

| Type | Operation          |
| ---- | ------------------ |
| 18   | Revoke Sponsorship |

{% enddocs %}

{% docs details_data_name %}
The name of the data entry which is no longer sponsored

### Only exists for the following operations:

| Type | Operation          |
| ---- | ------------------ |
| 18   | Revoke Sponsorship |

{% enddocs %}

{% docs details_from %}
The account address from which the payment/contract originates (the sender account)

### Only exists for the following operations:

| Type | Operation                   |
| ---- | --------------------------- |
| 1    | Payment                     |
| 2    | Path Payment Strict Receive |
| 13   | Path Payment Strict Send    |
| 19   | Clawback                    |
| 24   | Invoke Host Function        |

{% enddocs %}

{% docs details_from_muxed %}
If the account is multiplexed, the virtual address of the sender account

### Only exists for the following operations:

| Type | Operation                   |
| ---- | --------------------------- |
| 1    | Payment                     |
| 2    | Path Payment Strict Receive |
| 13   | Path Payment Strict Send    |
| 19   | Clawback                    |

{% enddocs %}

{% docs details_from_muxed_id %}
If the account is multiplexed, the integer representation of the virtual address of the sender account

### Only exists for the following operations:

| Type | Operation                   |
| ---- | --------------------------- |
| 1    | Payment                     |
| 2    | Path Payment Strict Receive |
| 13   | Path Payment Strict Send    |
| 19   | Clawback                    |

{% enddocs %}

{% docs details_funder %}
When a new account is created, an account address "funds" the new account

### Only exists for the following operations:

| Type | Operation      |
| ---- | -------------- |
| 0    | Create Account |

{% enddocs %}

{% docs details_funder_muxed %}
If the account is multiplexed, the virtual address of the account funding the new account

### Only exists for the following operations:

| Type | Operation      |
| ---- | -------------- |
| 0    | Create Account |

{% enddocs %}

{% docs details_funder_muxed_id %}
If the account is multiplexed, the integer representation of the account funding the new account

### Only exists for the following operations:

| Type | Operation      |
| ---- | -------------- |
| 0    | Create Account |

{% enddocs %}

{% docs details_high_threshold %}
The sum of the weight of all signatures that sign a transaction for the high threshold operation. The weight must exceed the set threshold for the operation to succeed.

### Only exists for the following operations:

| Type | Operation   |
| ---- | ----------- |
| 5    | Set Options |

#### Notes:

Each operation falls under a specific threshold category: low, medium or high. Thresholds define the level of privilege an operation needs in order to succeed (this is a security measure)

| Security | Operations                                                                   |
| -------- | ---------------------------------------------------------------------------- |
| Low      | Allow Trust, Set Trust Line Flags, Bump Sequence and Claim Claimable Balance |
| Medium   | Everything Else                                                              |
| High     | Account Merge, Set Options                                                   |

{% enddocs %}

{% docs details_home_domain %}
The home domain used for the stellar.toml file discovery

### Only exists for the following operations:

| Type | Operation   |
| ---- | ----------- |
| 5    | Set Options |

{% enddocs %}

{% docs details_inflation_dest %}
The account address specifying where to send inflation funds. The concept of inflation on the network has been discontinued

### Only exists for the following operations:

| Type | Operation   |
| ---- | ----------- |
| 5    | Set Options |

## _Removed Field_

- Inflation was retired from the network in 2019.
  {% enddocs %}

{% docs details_into %}
The account address receiving the deleted account's lumens. This is the account in which the intended deleted account will be merged

### Only exists for the following operations:

| Type | Operation     |
| ---- | ------------- |
| 8    | Account Merge |

{% enddocs %}

{% docs details_into_muxed %}
If the account is multiplexed, the virtual address of the account receive the deleted account's lumens

### Only exists for the following operations:

| Type | Operation     |
| ---- | ------------- |
| 8    | Account Merge |

{% enddocs %}

{% docs details_into_muxed_id %}
If the account is multiplexed, the integer representation of the account receiving the deleted account's lumens

### Only exists for the following operations:

| Type | Operation     |
| ---- | ------------- |
| 8    | Account Merge |

{% enddocs %}

{% docs details_limit %}
The upper bound amount of an asset that an account can hold

### Only exists for the following operations:

| Type | Operation    |
| ---- | ------------ |
| 6    | Change Trust |

{% enddocs %}

{% docs details_low_threshold %}
The sum of the weight of all signatures that sign a transaction for the low threshold operation. The weight must exceed the set threshold for the operation to succeed.

### Only exists for the following operations:

| Type | Operation   |
| ---- | ----------- |
| 5    | Set Options |

#### Notes:

Each operation falls under a specific threshold category: low, medium or high. Thresholds define the level of privilege an operation needs in order to succeed (this is a security measure)

| Security | Operations                                                                   |
| -------- | ---------------------------------------------------------------------------- |
| Low      | Allow Trust, Set Trust Line Flags, Bump Sequence and Claim Claimable Balance |
| Medium   | Everything Else                                                              |
| High     | Account Merge, Set Options                                                   |

{% enddocs %}

{% docs details_master_key_weight %}
An accounts private key is called the master key. For signing transactions, the account holder can specify a weight for the master key, which contributes to thresholds validation when processing a transaction.

- Domain Values: Integers from 1 to 255

### Only exists for the following operations:

| Type | Operation   |
| ---- | ----------- |
| 5    | Set Options |

#### Notes:

Defaults to 1
{% enddocs %}

{% docs details_med_threshold %}
The sum of the weight of all signatures that sign a transaction for the medium threshold operation. The weight must exceed the set threshold for the operation to succeed.

### Only exists for the following operations:

| Type | Operation   |
| ---- | ----------- |
| 5    | Set Options |

#### Notes:

Each operation falls under a specific threshold category: low, medium or high. Thresholds define the level of privilege an operation needs in order to succeed (this is a security measure)

| Security | Operations                                                                   |
| -------- | ---------------------------------------------------------------------------- |
| Low      | Allow Trust, Set Trust Line Flags, Bump Sequence and Claim Claimable Balance |
| Medium   | Everything Else                                                              |
| High     | Account Merge, Set Options                                                   |

{% enddocs %}

{% docs details_name %}
The manage data operation allows an account to write and store data directly on the ledger in a key value pair format. The name is the key for a data entry.

### Only exists for the following operations:

| Type | Operation   |
| ---- | ----------- |
| 10   | Manage Data |

#### Notes:

If the name is new, the manage data operation will add the given name/value pair to the account. If the name is already present, the associated value will be modified.
{% enddocs %}

{% docs details_offer_id %}
The unique id for the offer. This id can be joined with the 'offers' table

### Only exists for the following operations:

| Type | Operation          |
| ---- | ------------------ |
| 3    | Manage Sell Offer  |
| 12   | Manage Buy Offer   |
| 18   | Revoke Sponsorship |

{% enddocs %}

{% docs details_path %}
Path payments maximize the best exchange rate path when sending money from one asset to another asset.The intermediary assets that this path hops through will be reported in the record. This feature is especially useful when the market between the original asset pair is illiquid.

### Only exists for the following operations:

| Type | Operation                   |
| ---- | --------------------------- |
| 2    | Path Payment Strict Receive |
| 13   | Path Payment Strict Send    |

#### Notes:

Up to 6 paths are permitted for a single payment.
Example: sending EUR -- MXN could look like EUR -- BTC -- CNY -- XLM -- MXN to maximize the best exchange rate. Payments are atomic, so if an exchange in the middle of a path payment fails, the entire payment will fail which means the user will keep their original funds. They will not be stuck with an intermediary asset in the event of payment failure.
{% enddocs %}

{% docs details_price %}
The ratio of selling asset to buying asset. This is a number representing how many units of a selling asset it takes to get 1 unit of a buying asset.

### Only exists for the following operations:

| Type | Operation                 |
| ---- | ------------------------- |
| 3    | Manage Sell Offer         |
| 4    | Create Passive Sell Offer |
| 12   | Manage Buy Offer          |

{% enddocs %}

{% docs details_price_r %}
Precise representation of the buy and sell price of the assets on an offer. The n is the numerator, the d is the denominator. By calculating the ratio of n/d you can calculate the price of the bid or ask

### Only exists for the following operations:

| Type | Operation                 |
| ---- | ------------------------- |
| 3    | Manage Sell Offer         |
| 4    | Create Passive Sell Offer |
| 12   | Manage Buy Offer          |

{% enddocs %}

{% docs details_price_r_d %}
The price ratio of the sold asset: bought asset. When taken with price_n, the price can be calculated by price_n/price_d
{% enddocs %}

{% docs details_price_r_n %}
The price ratio of the sold asset: bought asset. When taken with price_d, the price can be calculated by price_n/price_d
{% enddocs %}

{% docs details_selling_asset_code %}
The 4 or 12 character code representation of the asset that is either sold or offered to sell in a trade

### Only exists for the following operations:

| Type | Operation                 |
| ---- | ------------------------- |
| 3    | Manage Sell Offer         |
| 4    | Create Passive Sell Offer |
| 12   | Manage Buy Offer          |

{% enddocs %}

{% docs details_selling_asset_issuer %}
The account address of the original asset issuer that created the asset sold or offered to sell

### Only exists for the following operations:

| Type | Operation                 |
| ---- | ------------------------- |
| 3    | Manage Sell Offer         |
| 4    | Create Passive Sell Offer |
| 12   | Manage Buy Offer          |

{% enddocs %}

{% docs details_selling_asset_type %}
The identifier for type of asset code, can be a alphanumeric with 4 characters, 12 characters or the native asset to the network, XLM.

### Only exists for the following operations:

| Type | Operation                 |
| ---- | ------------------------- |
| 3    | Manage Sell Offer         |
| 4    | Create Passive Sell Offer |
| 12   | Manage Buy Offer          |

#### Notes:

XLM is the native asset to the network. XLM has no asset code or issuer representation and will instead be displayed with an asset type of 'native'
{% enddocs %}

{% docs details_set_flags %}
Array of numeric values of the flags set for a given trustline in the operation

### Only exists for the following operations:

| Type | Operation            |
| ---- | -------------------- |
| 21   | Set Trust Line Flags |

#### Notes:

| Values | Flags          |
| ------ | -------------- |
| 1      | Auth Required  |
| 2      | Auth Revocable |
| 4      | Auth Immutable |

{% enddocs %}

{% docs details_set_flags_s %}
Array of string values of the flags set for a given trustline in the operation

### Only exists for the following operations:

| Type | Operation            |
| ---- | -------------------- |
| 21   | Set Trust Line Flags |

#### Notes:

| Flags          |
| -------------- |
| Auth Required  |
| Auth Revocable |
| Auth Immutable |

{% enddocs %}

{% docs details_signer_account_id %}
The address of the account of the signer no longer sponsored

### Only exists for the following operations:

| Type | Operation          |
| ---- | ------------------ |
| 18   | Revoke Sponsorship |

{% enddocs %}

{% docs details_signer_key %}
The address of the signer which is no longer sponsored

### Only exists for the following operations:

| Type | Operation          |
| ---- | ------------------ |
| 5    | Set Options        |
| 18   | Revoke Sponsorship |

{% enddocs %}

{% docs details_signer_weight %}
The weight of the new signer. For transactions, multiple accounts can sign a transaction from a source account. This weight contributes towards calculating whether the transaction exceeds the specified threshold weight to complete the transaction

### Only exists for the following operations:

| Type | Operation   |
| ---- | ----------- |
| 5    | Set Options |

{% enddocs %}

{% docs details_source_amount %}
The originating amount sent designated in the source asset

### Only exists for the following operations:

| Type | Operation                   |
| ---- | --------------------------- |
| 2    | Path Payment Strict Receive |
| 13   | Path Payment Strict Send    |

{% enddocs %}

{% docs details_source_asset_code %}
The 4 or 12 character code representation of the asset that is originally sent

### Only exists for the following operations:

| Type | Operation                   |
| ---- | --------------------------- |
| 2    | Path Payment Strict Receive |
| 13   | Path Payment Strict Send    |

{% enddocs %}

{% docs details_source_asset_issuer %}
The account address of the original asset issuer that created the asset sent

### Only exists for the following operations:

| Type | Operation                   |
| ---- | --------------------------- |
| 2    | Path Payment Strict Receive |
| 13   | Path Payment Strict Send    |

{% enddocs %}

{% docs details_source_asset_type %}
The identifier for type of asset code, can be a alphanumeric with 4 characters, 12 characters or the native asset to the network, XLM.

### Only exists for the following operations:

| Type | Operation                   |
| ---- | --------------------------- |
| 2    | Path Payment Strict Receive |
| 13   | Path Payment Strict Send    |

#### Notes:

XLM is the native asset to the network. XLM has no asset code or issuer representation and will instead be displayed with an asset type of 'native'
{% enddocs %}

{% docs details_source_max %}
The maxium amount to be sent, designated in the source asset

### Only exists for the following operations:

| Type | Operation                   |
| ---- | --------------------------- |
| 2    | Path Payment Strict Receive |

#### Notes:

Exchanging an asset causes a small amount of the asset value to be spent in fees and exchange rates. The sender can specify a maximum amount they are willing to send if the rates between the asset pair are bad.
{% enddocs %}

{% docs details_starting_balance %}
The amount of XLM to send to the newly created account.
The account starting balance will need to exceed the minimum balance necessary to hold an account on the Stellar Network

### Only exists for the following operations:

| Type | Operation      |
| ---- | -------------- |
| 0    | Create Account |

{% enddocs %}

{% docs details_to %}
The address of the account receiving the payment funds

### Only exists for the following operations:

| Type | Operation                   |
| ---- | --------------------------- |
| 1    | Payment                     |
| 2    | Path Payment Strict Receive |
| 13   | Path Payment Strict Send    |

{% enddocs %}

{% docs details_to_muxed %}
If the account is multiplexed, the virtual address of the account receiving the payment

### Only exists for the following operations:

| Type | Operation                   |
| ---- | --------------------------- |
| 1    | Payment                     |
| 2    | Path Payment Strict Receive |
| 13   | Path Payment Strict Send    |

{% enddocs %}

{% docs details_to_muxed_id %}
If the account is multiplexed, the integer representation of the virtual address of the recipient account

### Only exists for the following operations:

| Type | Operation                   |
| ---- | --------------------------- |
| 1    | Payment                     |
| 2    | Path Payment Strict Receive |
| 13   | Path Payment Strict Send    |

{% enddocs %}

{% docs details_trustee %}
The issuing account address (only present for 'credit' asset types)

### Only exists for the following operations:

| Type | Operation    |
| ---- | ------------ |
| 6    | Change Trust |
| 7    | Allow Trust  |

{% enddocs %}

{% docs details_trustee_muxed %}
If the issuing account address is multiplexed, the virtual address

### Only exists for the following operations:

| Type | Operation   |
| ---- | ----------- |
| 7    | Allow Trust |

{% enddocs %}

{% docs details_trustee_muxed_id %}
If the issuing account address is multiplexed, the integer representation of the virtual address

### Only exists for the following operations:

| Type | Operation   |
| ---- | ----------- |
| 7    | Allow Trust |

{% enddocs %}

{% docs details_trustline_account_id %}
The address of the account whose trustline is no longer sponsored

### Only exists for the following operations:

| Type | Operation          |
| ---- | ------------------ |
| 18   | Revoke Sponsorship |

{% enddocs %}

{% docs details_trustline_asset %}
The asset of the trustline which is no longer sponsored

### Only exists for the following operations:

| Type | Operation          |
| ---- | ------------------ |
| 18   | Revoke Sponsorship |

#### Notes:

A sponsor can determine they want to revoke sponsorship of certain assets but maintain the sponsorship of other assets
{% enddocs %}

{% docs details_trustor %}
The trusting account address, or the account being authorized or unauthorized

### Only exists for the following operations:

| Type | Operation           |
| ---- | ------------------- |
| 6    | Change Trust        |
| 7    | Allow Trust         |
| 21   | Set Trustline Flags |

{% enddocs %}

{% docs details_trustor_muxed %}
If the trusting account is multiplexed, the virtual address of the account

### Only exists for the following operations:

| Type | Operation    |
| ---- | ------------ |
| 6    | Change Trust |

{% enddocs %}

{% docs details_trustor_muxed_id %}
If the trusting account is multiplexed, the integer representation of the virtual address

### Only exists for the following operations:

| Type | Operation    |
| ---- | ------------ |
| 6    | Change Trust |

{% enddocs %}

{% docs details_value %}
The manage data operation allows an account to write and store data directly on the ledger in a key value pair format. The value is the value of a key for a data entry.

### Only exists for the following operations:

| Type | Operation   |
| ---- | ----------- |
| 10   | Manage Data |

{% enddocs %}

{% docs details_clear_flags %}
Array of numeric values of the flags cleared for a given trustline in the operation. If the flag was originally set, this will delete the flag

### Only exists for the following operations:

| Type | Operation           |
| ---- | ------------------- |
| 21   | Set Trustline Flags |

#### Notes:

| Values | Flags          |
| ------ | -------------- |
| 1      | Auth Required  |
| 2      | Auth Revocable |
| 4      | Auth Immutable |

{% enddocs %}

{% docs details_clear_flags_s %}
Array of string values of the flags cleared for a given trustline in the operation. If the flag was originally set, this will delete the flag

### Only exists for the following operations:

| Type | Operation           |
| ---- | ------------------- |
| 21   | Set Trustline Flags |

#### Notes:

| Flags          |
| -------------- |
| Auth Required  |
| Auth Revocable |
| Auth Immutable |

{% enddocs %}

{% docs details_destination_min %}
The minimum amount to be received, designated in the expected destination asset

### Only exists for the following operations:

| Type | Operation                |
| ---- | ------------------------ |
| 13   | Path Payment Strict Send |

#### Notes:

Exchanging an asset causes a small amount of the asset value to be spent in fees and exchange rates. The sender can specify a guaranteed minimum amount they want sent to the recipient to ensure they receive a specified value.
{% enddocs %}

{% docs details_bump_to %}
The new desired value of the source account's sequence number

### Only exists for the following operations:

| Type | Operation     |
| ---- | ------------- |
| 11   | Bump Sequence |

{% enddocs %}

{% docs details_authorize_to_maintain_liabilities %}
Indicates whether the trustline is authorized. 0 is if the account is not authorized to transact with the asset in any way. 1 if the account is authorized to transact with the asset. 2 if the account is authorized to maintain orders, but not to perform other transactions.

### Only exists for the following operations:

| Type | Operation   |
| ---- | ----------- |
| 7    | Allow Trust |

{% enddocs %}

{% docs details_clawback_enabled %}
Indicates whether the asset can be clawed back by the asset issuer

### Only exists for the following operations:

| Type | Operation   |
| ---- | ----------- |
| 5    | Set Options |
| 7    | Allow Trust |

{% enddocs %}

{% docs details_sponsor %}
The account address of another account that maintains the minimum balance in XLM for the source account to complete operations

- May exist for any operation type
  {% enddocs %}

{% docs details_sponsored_id %}
The account address of the account which will be sponsored

### Only exists for the following operations:

| Type | Operation                        |
| ---- | -------------------------------- |
| 16   | Begin Sponsoring Future Reserves |

{% enddocs %}

{% docs details_begin_sponsor %}
The account address of the account which initiated the sponsorship

### Only exists for the following operations:

| Type | Operation                      |
| ---- | ------------------------------ |
| 17   | End Sponsoring Future Reserves |

{% enddocs %}

{% docs details_begin_sponsor_muxed %}
If the initiating sponsorship account is multiplexed, the virtual address

### Only exists for the following operations:

| Type | Operation                      |
| ---- | ------------------------------ |
| 17   | End Sponsoring Future Reserves |

{% enddocs %}

{% docs details_begin_sponsor_muxed_id %}
If the initiating sponsorship account is multiplexed, the integer representation of the virtual address

### Only exists for the following operations:

| Type | Operation                      |
| ---- | ------------------------------ |
| 17   | End Sponsoring Future Reserves |

{% enddocs %}

{% docs details_liquidity_pool_id %}
Unique identifier for a liquidity pool

### Only exists for the following operations:

| Type | Operation               |
| ---- | ----------------------- |
| 6    | Change Trust            |
| 18   | Revoke Sponsorship      |
| 22   | Liquidity Pool Deposit  |
| 23   | Liquidity Pool Withdraw |

#### Notes:

Liquidity pools are automated money markets between an asset pair. A given pool will only ever have two assets unless there is a protocol change
{% enddocs %}

{% docs details_reserve_a_asset_type %}
The identifier for type of asset code, can be a alphanumeric with 4 characters, 12 characters or the native asset to the network, XLM.

### Only exists for the following operations:

| Type | Operation               |
| ---- | ----------------------- |
| 22   | Liquidity Pool Deposit  |
| 23   | Liquidity Pool Withdraw |

{% enddocs %}

{% docs details_reserve_a_asset_code %}
The 4 or 12 character code representation of the asset of one of the two asset pairs in a liquidity pool

### Only exists for the following operations:

| Type | Operation               |
| ---- | ----------------------- |
| 22   | Liquidity Pool Deposit  |
| 23   | Liquidity Pool Withdraw |

{% enddocs %}

{% docs details_reserve_a_asset_issuer %}
The account address of the original asset issuer that created one of the two asset pairs in the liquidity pool

### Only exists for the following operations:

| Type | Operation               |
| ---- | ----------------------- |
| 22   | Liquidity Pool Deposit  |
| 23   | Liquidity Pool Withdraw |

{% enddocs %}

{% docs details_reserve_a_max_amount %}
The maximum amount of reserve a that can be deposited into the pool.

### Only exists for the following operations:

| Type | Operation              |
| ---- | ---------------------- |
| 22   | Liquidity Pool Deposit |

#### Notes:

Deposit operations calculate via formula how much of both asset a and asset b should be deposited out of a source account and into a pool. The source account must deposit an equivalent value of both asset a and b. Since markets fluctuate, a maximum amount will specify the upper limit of an asset the account is willing to deposit.
{% enddocs %}

{% docs details_reserve_a_deposit_amount %}
The amount of reserve a that ended up actually deposited into the pool

### Only exists for the following operations:

| Type | Operation              |
| ---- | ---------------------- |
| 22   | Liquidity Pool Deposit |

{% enddocs %}

{% docs details_reserve_b_asset_type %}
The identifier for type of asset code, can be a alphanumeric with 4 characters, 12 characters or the native asset to the network, XLM.

### Only exists for the following operations:

| Type | Operation               |
| ---- | ----------------------- |
| 22   | Liquidity Pool Deposit  |
| 23   | Liquidity Pool Withdraw |

{% enddocs %}

{% docs details_reserve_b_asset_code %}
The 4 or 12 character code representation of the asset of one of the two asset pairs in a liquidity pool.

### Only exists for the following operations:

| Type | Operation               |
| ---- | ----------------------- |
| 22   | Liquidity Pool Deposit  |
| 23   | Liquidity Pool Withdraw |

{% enddocs %}

{% docs details_reserve_b_asset_issuer %}
The account address of the original asset issuer that created one of the two asset pairs in the liquidity pool.

### Only exists for the following operations:

| Type | Operation               |
| ---- | ----------------------- |
| 22   | Liquidity Pool Deposit  |
| 23   | Liquidity Pool Withdraw |

{% enddocs %}

{% docs details_reserve_b_max_amount %}
The maximum amount of reserve b that can be deposited into the pool.

### Only exists for the following operations:

| Type | Operation              |
| ---- | ---------------------- |
| 22   | Liquidity Pool Deposit |

#### Notes:

Deposit operations calculate via formula how much of both asset a and asset b should be deposited out of a source account and into a pool. The source account must deposit an equivalent value of both asset a and b. Since markets fluctuate, a maximum amount will specify the upper limit of an asset the account is willing to deposit.
{% enddocs %}

{% docs details_reserve_b_deposit_amount %}
The amount of reserve b that ended up actually deposited into the pool.

### Only exists for the following operations:

| Type | Operation              |
| ---- | ---------------------- |
| 22   | Liquidity Pool Deposit |

{% enddocs %}

{% docs details_min_price %}
The floating point value indicating the minimum exchange rate for this deposit operation. Reported as Reserve A / Reserve B.

### Only exists for the following operations:

| Type | Operation              |
| ---- | ---------------------- |
| 22   | Liquidity Pool Deposit |

#### Notes:

Market rates fluctuate for pricing and the source account can specify a maximum price they expect to receive as a ratio of the two assets in the pool
{% enddocs %}

{% docs details_min_price_r %}
A fractional representation of the prices of the two assets in a pool. The n is the numerator (value of asset a) and the d is the denominator (value of asset b).

### Only exists for the following operations:

| Type | Operation              |
| ---- | ---------------------- |
| 22   | Liquidity Pool Deposit |

{% enddocs %}

{% docs details_max_price %}
The floating point value indicating the maximum exchange rate for this deposit operation. Reported as Reserve A / Reserve B.

### Only exists for the following operations:

| Type | Operation              |
| ---- | ---------------------- |
| 22   | Liquidity Pool Deposit |

#### Notes:

Market rates fluctuate for pricing and the source account can specify a maximum price they expect to receive as a ratio of the two assets in the pool
{% enddocs %}

{% docs details_max_price_r %}
A fractional representation of the prices of the two assets in a pool. The n is the numerator (value of asset a) and the d is the denominator (value of asset b).

### Only exists for the following operations:

| Type | Operation              |
| ---- | ---------------------- |
| 22   | Liquidity Pool Deposit |

{% enddocs %}

{% docs details_shares_received %}
A floating point number representing the number of pool shares received for this deposit. A pool share is a compilation of both asset a and asset b reserves. It is not possible to own only asset a or asset b in a pool.

### Only exists for the following operations:

| Type | Operation              |
| ---- | ---------------------- |
| 22   | Liquidity Pool Deposit |

{% enddocs %}

{% docs details_reserve_a_min_amount %}
The minimum amount of reserve a that can be withdrawn from the pool.

### Only exists for the following operations:

| Type | Operation               |
| ---- | ----------------------- |
| 23   | Liquidity Pool Withdraw |

{% enddocs %}

{% docs details_reserve_a_withdraw_amount %}
The amount of reserve a that ended up actually withdrawn from the pool.

### Only exists for the following operations:

| Type | Operation               |
| ---- | ----------------------- |
| 23   | Liquidity Pool Withdraw |

{% enddocs %}

{% docs details_reserve_b_min_amount %}
The minimum amount of reserve b that can be withdrawn from the pool.

### Only exists for the following operations:

| Type | Operation               |
| ---- | ----------------------- |
| 23   | Liquidity Pool Withdraw |

{% enddocs %}

{% docs details_reserve_b_withdraw_amount %}
The amount of reserve b that ended up actually withdrawn from the pool.

### Only exists for the following operations:

| Type | Operation               |
| ---- | ----------------------- |
| 23   | Liquidity Pool Withdraw |

{% enddocs %}

{% docs details_shares %}
The number of shares withdrawn from the pool. It is not possible to withdraw only asset a or asset b, equal value must be withdrawn from the pool.

### Only exists for the following operations:

| Type | Operation               |
| ---- | ----------------------- |
| 23   | Liquidity Pool Withdraw |

{% enddocs %}

{% docs details_function %}
Soroban field - invoke_host_function function type

| Type                                               |
| -------------------------------------------------- |
| HostFunctionTypeHostFunctionTypeInvokeContract     |
| HostFunctionTypeHostFunctionTypeCreateContract     |
| HostFunctionTypeHostFunctionTypeUploadContractWasm |

### Only exists for the following operations:

| Type | Operation            |
| ---- | -------------------- |
| 24   | Invoke Host Function |

{% enddocs %}

{% docs from_address %}
Soroban field - address used to create the Soroban contract

### Only exists for the following operations:

| Type | Operation            |
| ---- | -------------------- |
| 24   | Invoke Host Function |

{% enddocs %}

{% docs from_asset %}
Soroban field - asset used to create the Soroban contract

_Note:_ Only applies to Stellar Asset Contracts

### Only exists for the following operations:

| Type | Operation            |
| ---- | -------------------- |
| 24   | Invoke Host Function |

{% enddocs %}

{% docs details_asset_balance_changes %}
Soroban field - asset balance changes from invoke host function

### Only exists for the following operations:

| Type | Operation            |
| ---- | -------------------- |
| 24   | Invoke Host Function |

{% enddocs %}

{% docs details_parameters %}
Soroban field - parameters from contract function call

### Only exists for the following operations:

| Type | Operation            |
| ---- | -------------------- |
| 24   | Invoke Host Function |

{% enddocs %}

{% docs details_type %}
Soroban field - type of soroban operation

| Type                 |
| -------------------- |
| invoke_contract      |
| create_contract      |
| upload_wasm          |
| extend_footprint_ttl |
| restore_footprint    |

### Only exists for the following operations:

| Type | Operation            |
| ---- | -------------------- |
| 24   | Invoke Host Function |

{% enddocs %}

{% docs details_soroban_operation_type %}
Soroban field - soroban invoke function (invoke contract, create contract, upload wasm)

### Only exists for the following operations:

| Type | Operation            |
| ---- | -------------------- |
| 24   | Invoke Host Function |

{% enddocs %}

{% docs details_asset_id %}
The identifier of the asset involved in the operation. This field provides details about the specific asset being operated on, such as in payment or transfer operations.
{% enddocs %}

{% docs details_buying_asset_id %}
The identifier of the asset being bought in the operation. This is relevant for trade and offer operations, where one asset is exchanged for another.
{% enddocs %}

{% docs details_selling_asset_id %}
The identifier of the asset being sold in the operation. This field is used in trade and offer operations, where one asset is exchanged for another.
{% enddocs %}

{% docs details_source_asset_id %}
The identifier of the source asset in the operation. This is used in payment operations where an asset is transferred or converted from one form to another.
{% enddocs %}

{% docs details_reserve_a_asset_id %}
The identifier of the first reserve asset in a liquidity pool or similar construct. This field is relevant for operations involving liquidity pools, where multiple assets are pooled together.
{% enddocs %}

{% docs details_reserve_b_asset_id %}
The identifier of the second reserve asset in a liquidity pool or similar construct. This field complements `details.reserve_a_asset_id` in describing the assets involved in a liquidity pool.
{% enddocs %}

{% docs details_ledgers_to_expire %}
The number of ledgers after which the operation will expire if its not executed.
{% enddocs %}

{% docs details_balance_id_strkey %}
Strkey of the balance id
{% enddocs %}

{% docs details_claimable_balance_id_strkey %}
Strkey of the balance id
{% enddocs %}

{% docs details_liquidity_pool_id_strkey %}
Strkey of the liquidity_pool_id
{% enddocs %}

{% docs details_parameters_json %}
JSON formatted output of parameters from contract call
{% enddocs %}

{% docs details_parameters_json_decoded %}
JSON formatted output of xdr decoded parameters from contract call
{% enddocs %}
