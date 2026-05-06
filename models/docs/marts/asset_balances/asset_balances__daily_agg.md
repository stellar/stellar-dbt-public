[comment]: < Asset Balances Daily Agg -

{% docs asset_balances__daily_agg %}

Table containing the daily aggregate of asset balances.

For contract tokens, `asset_code` is resolved via `int_contract_asset_codes`: it coalesces the asset_code from SAC token transfer events, then the SEP-41 `symbol` from contract storage metadata, then falls back to the `contract_id` itself so contract-token rows are never grouped under a null asset_code.

{% enddocs %}

{% docs day_agg %}

Date by which all metrics are aggregated. In the agg_network_stats table, all aggregations are daily.

{% enddocs %}

{% docs liquidity_pool_balance %}

The sum of balances across all liquidity pools for a given asset.

{% enddocs %}

{% docs offer_balance %}

The sum of balances across all selling liabilities(SDEX only) for a given asset.

{% enddocs %}

{% docs trustline_balance %}

The sum of trustline balance for a given asset.

{% enddocs %}

{% docs contract_balance %}

The sum of contract balance for a given asset.

{% enddocs %}

{% docs total_accounts_with_liquidity_pool_balance %}

The count of positive liquidity pool balance holders for a given asset.

{% enddocs %}

{% docs total_accounts_with_offer_balance %}

The count of positive offer balance holders for a given asset.

{% enddocs %}

{% docs total_accounts_with_trustline_balance %}

The count of positive trustline balance holders for a given asset.

{% enddocs %}

{% docs total_accounts_with_contract_balance %}

The count of positive contract balance holders for a given asset.

{% enddocs %}
