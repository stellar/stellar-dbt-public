[comment]: < History Trades -

{% docs history_trades %}
History trades reports trading activity that occurs in both the decentralized exchange and automated money markets. Trades fulfill one of four operations: manage buy offers, manage sell offers and path payments (strict send and receive). Trades can be executed either against the orderbook or a liquidity pool that contains both bid and ask asset pair. Trades can be either path payments or offers that are fully or partially fulfilled, which means that the trade can be split into segments. A full trade is compromised of all "order" numbers for a given history_operation_id.
{% enddocs %}

{% docs history_operation_id %}
The operation id associated with the executed trade. The total amount traded in an operation can be broken up into multiple smaller trades spread across multiple orders by multiple parties

- Natural Key
- Cluster Field
- Required Field

#### Notes:

There is a many to one relationship for history_operation_id with the history_operations table.
{% enddocs %}

{% docs order %}
The sequential number assigned the portion of a trade that is executed within a operation. The history_operation_id and order number together represent a unique trade segment.

- Natural Key
- Required Field
  {% enddocs %}

{% docs selling_account_address %}
The account address of the selling party
{% enddocs %}

{% docs trade_selling_asset_code %}
The 4 or 12 character code of the sold asset within a trade

#### Notes:

Asset codes have no guarantees of uniqueness. The combination of asset code, issuer and type represents a distinct asset
{% enddocs %}

{% docs trade_selling_asset_issuer %}
The account address of the original asset issuer for the sold asset within a trade
{% enddocs %}

{% docs trade_selling_asset_type %}
The identifier for type of asset code used for the sold asset within the trade

- Required Field

#### Notes:

XLM is the native asset to the network. XLM has no asset code or issuer representation and will instead be displayed with an asset type of 'native'
{% enddocs %}

{% docs trade_selling_amount %}
The amount of sold asset that was moved from the seller account to the buyer account, reported in terms of the sold amount

- Required Field
  {% enddocs %}

{% docs buying_account_address %}
The account address of the buying party
{% enddocs %}

{% docs trade_buying_asset_code %}
The 4 or 12 character code of the bought asset within a trade

#### Notes:

Asset codes have no guarantees of uniqueness. The combination of asset code, issuer and type represents a distinct asset
{% enddocs %}

{% docs trade_buying_asset_issuer %}
The account address of the original asset issuer for the bought asset within a trade
{% enddocs %}

{% docs trade_buying_asset_type %}
The identifier for type of asset code used for the bought asset within the trade

- Required Field

#### Notes:

XLM is the native asset to the network. XLM has no asset code or issuer representation and will instead be displayed with an asset type of 'native'
{% enddocs %}

{% docs trade_buying_amount %}
The amount of purchased asset that was moved from the seller account into the buying account, reported in terms of the bought asset.

- Required Field
  {% enddocs %}

{% docs trade_price_n %}
The price ratio of the sold asset: bought asset. When taken with price_d, the price can be calculated by price_n/price_d
{% enddocs %}

{% docs trade_price_d %}
The price ratio of the sold asset: bought asset. When taken with price_n, the price can be calculated by price_n/price_d
{% enddocs %}

{% docs selling_offer_id %}
The offer ID in the orderbook of the selling offer. If this offer was immediately and fully consumed, this will be a synthetic ID.
{% enddocs %}

{% docs buying_offer_id %}
The offer ID in the orderbook of the buying offer. If this offer was immediately and fully consumed, this will be a synthetic ID.
{% enddocs %}

{% docs selling_liquidity_pool_id %}
The unique identifier for a liquidity pool if the trade was executed against a liquidity pool instead of the orderbook
{% enddocs %}

{% docs liquidity_pool_fee %}
The percentage fee (in basis points) of the total fee collected by the liquidity pool for executing the trade.
The fee is pooled and distributed back to liquidity pool shareholders to incentivize users to stake money in the pool.

| Default Values |
| -------------- |
| 30             |

#### Notes:

Liquidity pool fees can only change with protocol changes to the network itself
{% enddocs %}

{% docs trade_type %}
Indicates whether the trade was executed against the orderbook (decentralized exchange) or liquidity pool.

| Code | Value                         |
| ---- | ----------------------------- |
| 1    | Descentralized Exchange Trade |
| 2    | Liquidity Pool Trade          |

{% enddocs %}

{% docs rounding_slippage %}
Applies to liquidity pool trades only. With fractional amounts of an asset traded, the network must round a fraction to the nearest whole number. This can cause the trade to "slip" price by a percentage compared with the original offer. Rounding slippage reports the percentage that dust trades slip before executing.

#### Notes:

Defaults to 1
Rounding Slippage is always unprofitable for the trader and is not a valid way to try and extract more value from the network.
{% enddocs %}

{% docs seller_is_exact %}
Indicates whether the buying or selling party trade was impacted by rounding slippage. If true, the buyer was impacted. If false, the seller was impacted
{% enddocs %}

{% docs selling_liquidity_pool_id_strkey %}
The unique strkey identifier for a liquidity pool if the trade was executed against a liquidity pool instead of the orderbook
{% enddocs %}
