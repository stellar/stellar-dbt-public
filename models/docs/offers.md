[comment]: < Offers -

{% docs offers %}
The offers table stores the current status of an offer in the Orderbook on Stellar. In order to create an order, the account must hold the asset it wants to use to buy the desired asset. The account must also trust the issuer of the asset it’s trying to buy. Orders behave like limit orders in traditional markets. If the order is marketable (meaning that it is at or below market price), it is filled at the existing order price. If the order is not marketable, it is saved on the orderbook until it is consumed by another order, path payment or is canceled by the user. Offers that do not have a corresponding trade in the `history_trades` table were canceled by the user. To delete an order, the user must manage the buy/sell offer and set the bid/ask amount to 0. Orders are executed on a price-time priority, meaning orders will be executed first based on price; for orders placed at the same price, the older order is given precendence. 
{% enddocs %}

{% docs seller_id %}
The account address that is making this offer.

- Cluster Field
- Required Field
{% enddocs %}

{% docs offer_id %}
The unique identifier for this offer.

- Required Field
{% enddocs %}

{% docs offers_selling_asset_type %}
The identifier for type of asset code, can be a alphanumeric with 4 characters, 12 characters or the native asset to the network, XLM.

- Required Field
{% enddocs %}

{% docs offers_selling_asset_code %}
The 4 or 12 character code representation of the asset offered to be sold
{% enddocs %}

{% docs offers_selling_asset_issuer %}
The account address of the original asset issuer that minted the asset which will be sold in exchange for another asset.
{% enddocs %}

{% docs offers_buying_asset_type %}
The identifier for type of asset code, can be a alphanumeric with 4 characters, 12 characters or the native asset to the network, XLM.
{% enddocs %}

{% docs offers_buying_asset_code %}
The 4 or 12 character code representation of the asset desired to be purchased.
{% enddocs %}

{% docs offers_buying_asset_issuer %}
The account address of the original asset issuer that minted the asset which will be bought in exchange for a currently held asset.
{% enddocs %}

{% docs offers_amount %}
The amount of selling that the account making this offer is willing to sell.

- Required Field
{% enddocs %}

{% docs offers_price_n %}
The numerator of the precise representation of the buy and sell price of assets on offer (The buy amount desired).

- Required Field

#### Notes:
If an offer wants to sell 10 XLM in exchange for 1 USD, the numerator will be 1.
{% enddocs %}

{% docs offers_price_d %}
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

{% docs offers_flags %}
Denotes the enabling/disabling of certain asset issuer privileges.

#### Notes:

| Flag    | Meaning                      |
|---------|------------------------------|
| 0       | Default                      |
| 1       | Passive (offer with this flag will not act on and take a reverse offer of equal price)        |
{% enddocs %}

{% docs offers_last_modified_ledger %}
The ledger sequence number when the ledger entry (this unique signer for the account) was modified. Deletions do not count as a modification and will report the prior modification sequence number.

- Natural Key
- Cluster Field
- Required Field
{% enddocs %}

{% docs offers_ledger_entry_change %}
Code that describes the ledger entry change type that was applied to the ledger entry.

- Required Field

#### Notes:
Valid entry change types are 0, 1, and 2 for ledger entries of type `offers`. 

| Value    | Description                |
|----------|----------------------------|
| 0        | Ledger Entry Created       |
| 2        | Ledger Entry Deleted       |
{% enddocs %}

{% docs offers_deleted %}
Indicates whether the ledger entry (offer id) has been deleted or not. Once an entry is deleted, it cannot be recovered.

- Required Field
{% enddocs %}