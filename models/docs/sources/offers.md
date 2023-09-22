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


