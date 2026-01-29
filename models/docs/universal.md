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

Asset codes have no guarantees of uniqueness. The combination of asset code, issuer and type represents a distinct asset
{% enddocs %}

{% docs asset_issuer %}
The account address of the original asset issuer that created the asset.
{% enddocs %}

{% docs amount %}
The raw number of units of an asset. Precision for an amount is 10^-7 of the asset token. For example, XLM is scaled down to a denomination of a **stroop,** where 10,000,000 stroops = 1 XLM. More information about amount precision can be found [here](https://developers.stellar.org/docs/fundamentals-and-concepts/stellar-data-structures/assets#amount-precision).

- Required Field
  {% enddocs %}

{% docs precision %}
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
