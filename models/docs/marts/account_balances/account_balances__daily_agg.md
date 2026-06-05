[comment]: < Account Balances Daily Agg -

{% docs account_balances__daily_agg %}

Table containing the daily aggregate of account balances.

For contract tokens, `asset_code` is resolved via `int_asset_metadata`: it coalesces the asset_code from SAC token transfer events with the SEP-41 `symbol` from contract storage metadata. The value is null when a contract publishes neither.

{% enddocs %}
