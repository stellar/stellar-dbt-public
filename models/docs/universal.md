[comment]: < Universal >

{% docs asset_type %}
The identifier for type of asset code, can be an alphanumeric with 4 characters, 12 characters or the native asset to the network, XLM.

- Required Field

#### Notes:

XLM is the native asset to the network. XLM has no asset code or issuer representation and will instead be displayed with an asset type of 'native'
{% enddocs %}

{% docs asset_id %}
The Farm Hash encoding of Asset Code + Asset Issuer + Asset Type. This field is optimized for cross table joins since integer joins are less expensive than the original asset id components.

{% enddocs %}

{% docs unique_id %}
Current snapshot tables (tables that end in `*_current`) require a singular, unique identifier so that only records that change are updated. This column is a concatenation of the natural keys to create a unique key.
{% enddocs %}

{% docs asset_code %}
The 4 or 12 character code representation of the asset on the network.

#### Notes:

Asset codes have no guarantees of uniqueness. The combination of asset code, issuer and type represents a distinct asset.

For contract tokens, `asset_code` is resolved via `int_asset_metadata`, which coalesces the asset_code from SAC transfer events with the SEP-41 `symbol` from contract storage metadata. The value is null when a contract publishes neither a SAC asset_code nor a SEP-41 `symbol` — recognized assets are enriched upstream in `stg_assets`, so a null `asset_code` on a contract-token row means the contract publishes no on-chain identifying metadata.
{% enddocs %}

{% docs asset_issuer %}
The account address of the original asset issuer that created the asset.
{% enddocs %}

{% docs amount %}
The raw number of units of an asset. Precision for an amount is 10^-7 of the asset token. For example, XLM is scaled down to a denomination of a **stroop,** where 10,000,000 stroops = 1 XLM. More information about amount precision can be found [here](https://developers.stellar.org/docs/fundamentals-and-concepts/stellar-data-structures/assets#amount-precision).

- Required Field
  {% enddocs %}

{% docs decimal_precision %}
The number of decimal places of precision an asset supports.

- Required Field

#### Notes:

Standard Stellar assets (AlphaNum4, AlphaNum12, and Native) follow a fixed precision of 7 (10^-7).
However, Soroban contract tokens can define custom precision, often set during contract initialization. For example, some Real World Assets (RWAs) use a precision of 5 or 0. Per the SEP-41 standard, this metadata is written to the ledger in a specific format to allow for direct reading. If precision is not explicitly defined in the contract metadata, it defaults to 7.
{% enddocs %}

{% docs price_n %}
The numerator of the precise representation of the buy and sell price of assets on offer (The buy amount desired).

- Required Field

#### Notes:

If an offer wants to sell 10 XLM in exchange for 1 USD, the numerator will be 1.
{% enddocs %}

{% docs price_d %}
The denominator of the precise represenation of the buy and sell price of assets on offer (The sell amount offered).

- Required Field

#### Notes:

If an offer wants to sell 10 XLM in exchange for 1 USD, the numerator will be 1.
{% enddocs %}

{% docs price %}
How many units of buying it takes to get 1 unit of selling. This number is the decimal form of pricen / priced.

- Required Field

#### Notes:

If an offer wants to sell 10 XLM for 1 USD, the price will be 0.10 USD.
{% enddocs %}

{% docs batch_id %}
String representation of the run id for a given DAG in Airflow. Takes the form of "scheduled__<batch_end_date>-<dag_alias>". Batch ids are unique to the batch and help with monitoring and rerun capabilities
{% enddocs %}

{% docs batch_run_date %}
The start date for the batch interval. When taken with the date in the batch_id, the date represents the interval of ledgers processed. The batch run date can be seen as a proxy of closed_at for a ledger.
{% enddocs %}

{% docs batch_insert_ts %}
The timestamp in UTC when a batch of records was inserted into the database. This field can help identify if a batch executed in real time or as part of a backfill. The timestamp should not be used during ad hoc analysis and is useful for data engineering purposes.
{% enddocs %}

{% docs address %}
The address of the account. The address is the account's public key encoded in base32. All account addresses start with a `G`
{% enddocs %}

{% docs address_muxed %}
Muxed accounts are embedded into the protocol for convenience and standardization. They distinguish individual accounts that all exist under a single, traditional Stellar account. They combine the familiar GABC… address with a 64-bit integer ID. More info can be found on [Stellar Docs](https://developers.stellar.org/docs/encyclopedia/pooled-accounts-muxed-accounts-memos#muxed-accounts)
{% enddocs %}

{% docs ledger_closed_at %}
The timestamp in UTC when the ledger with this trade was closed.
{% enddocs %}

{% docs contract_id %}
Soroban contract id
{% enddocs %}

{% docs asset_contract_id %}
contract id of the SAC or contract token.
{% enddocs %}

{% docs asset_created_at %}
Timestamp when the asset was minted to stellar network.
{% enddocs %}

{% docs details_extend_to %}
Soroban field - ledger extended to

### Only exists for the following operations:

| Type | Operation            |
| ---- | -------------------- |
| 25   | Extend Footprint Ttl |

{% enddocs %}

{% docs contract_code_hash %}
Soroban contract code hash
{% enddocs %}

{% docs ledger_key_hash %}
Hash of the ledgerKey which is a subset of the ledgerEntry. The subset of ledgerEntry fields depends on ledgerEntryType.
{% enddocs %}

{% docs closed_at %}
Timestamp in UTC when this ledger closed and committed to the network. Ledgers are expected to close ~every 5 seconds
{% enddocs %}

{% docs ledger_sequence %}
The sequence number of this ledger. It represents the order of the ledger within the Stellar blockchain. Each ledger has a unique sequence number that increments with every new ledger, ensuring that ledgers are processed in the correct order.

- Cluster Field
- Required Field
{% enddocs %}

{% docs airflow_start_ts %}
The timestamp when the airflow job starts. The airflow job writes data to the
bigquery tables. This can be used to know if data was added as backfill. Example; When close_date is old, however airflow_start_ts is recent.
{% enddocs %}

{% docs valid_from %}
The timestamp when this snapshot row was first inserted and became effective. This helps in tracking changes over time.
{% enddocs %}

{% docs valid_to %}
The timestamp when this row is no longer valid. If `null`, the setting is currently active.
{% enddocs %}

{% docs ledger_entry_type %}
The type ledger entry for data stored such as contract data or liquidity pools
{% enddocs %}

{% docs price_as_of_day %}

The day when the asset price is valid.

{% enddocs %}

{% docs open_usd %}
The open price in USD for the day.
{% enddocs %}

{% docs high_usd %}
The high price in USD for the day.
{% enddocs %}

{% docs low_usd %}
The low price in USD for the day.
{% enddocs %}

{% docs close_usd %}
The close price in USD for the day.
{% enddocs %}

{% docs deleted %}
Indicates whether the ledger entry (account, claimable balance, trust line, offer, liquidity pool) has been deleted or not. Once an entry is deleted, it cannot be recovered.

All state tables maintain history for deleted ledger entries.

- Required Field
  {% enddocs %}

{% docs last_modified_ledger %}
The ledger sequence number when the ledger entry was last modified. Deletions do not count as a modification and will report the prior modification sequence number

- Natural Key
- Cluster Field
- Required Field

#### Notes:

As an example, if an account updates a signer's weight at sequence 1234 and then decides to delete the signer at 2345, the deleted record will still have a modified sequence of 1234. The `last_modified_ledger` **is not** a proxy for entry deletion time and should not be used in such a manner. Deletion times can be approximated with `batch_run_date`.
{% enddocs %}

{% docs ledger_entry_change %}
Code that describes the ledger entry change type that was applied to the ledger entry.

- Required Field

#### Notes:

Not every ledger entry can be updated, some are only created or deleted. Pay attention to types that are not valid for certain ledger entries.

| Value | Description          | **Not** Valid For  |
| ----- | -------------------- | ------------------ |
| 0     | Ledger Entry Created |                    |
| 1     | Ledger Entry Updated | claimable balances |
| 2     | Ledger Entry Deleted |                    |

{% enddocs %}

{% docs sponsor %}
The account address of the sponsor who is paying the reserves for this ledger entry.

The following ledger entry types can be sponsored:

- accounts
- account signers
- claimable balances
- trust lines

#### Notes:

Sponsors of claimable balances are the accounts that created the balance.
{% enddocs %}

{% docs account_id %}
The address of the account. The address is the account's public key encoded in base32. All account addresses start with a 'G'.

- Natural Key
- Cluster Field
- Required Field
  {% enddocs %}

{% docs transaction_hash %}
A hex-encoded SHA-256 hash of this transaction's XDR-encoded form.

- Required Field
  {% enddocs %}

{% docs transaction_id %}
A unique identifier for this transaction.

- Primary Key
- Natural Key
- Cluster Field
- Required Field
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

{% docs successful %}
Indicates if this transaction was successful or not

#### Notes:

A transaction's success does not indicate whether it was included and written to a ledger. It only indicates whether the operations in the transaction were successfully applied to mutate the ledger state.
{% enddocs %}

{% docs balance_id_strkey %}
The claimable balance identifier encoded as a strkey, a base32 string starting with `B`. This is the form Horizon and the SDKs use; `balance_id` holds the same identifier as hex.
{% enddocs %}

{% docs liquidity_pool_id_strkey %}
The liquidity pool identifier encoded as a strkey, a base32 string starting with `L`. This is the form Horizon and the SDKs use; `liquidity_pool_id` holds the same identifier as hex.
{% enddocs %}

{% docs ledger_key_hash_base_64 %}
The ledger key of the entry as base64-encoded XDR, the form Soroban RPC's `getLedgerEntries` accepts. `ledger_key_hash` is the hex hash of this same key.
{% enddocs %}
