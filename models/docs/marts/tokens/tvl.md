[comment]: < TVL Aggregate -

{% docs day %}
The date for the aggregation result.
{% enddocs %}

{% docs accounts_tvl_raw %}
The total selling liabilities on the built-in Stellar Decentralized Exchange. If an account has an open sell offer in the Stellar orderbook, the account must maintain a balance with sufficient funds to execute the trade. These tokens are locked until the order is filled or cancelled. This measure only includes XLM, Stellar Lumens, reported in stroops. One stroop = 0.0000001XLM 
{% enddocs %}

{% docs trustlines_tvl_usd %}
The total value locked (TVL) denominated in USD for a given date. Aggregated across trustlines selling liabilities
{% enddocs %}

{% docs total_tvl_usd %}
The total value locked (TVL) denominated in USD for a given date. Aggregated across relevant ledger entries (e.g., accounts, trustlines).
{% enddocs %}
