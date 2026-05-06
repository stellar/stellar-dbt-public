[comment]: < Account Balances Daily Agg -

{% docs account_balances__daily_agg %}

Table containing the daily aggregate of account balances.

For contract tokens, `asset_code` is resolved via `int_contract_asset_codes`: it coalesces the asset_code from SAC token transfer events, then the SEP-41 `symbol` from contract storage metadata, then falls back to the `contract_id` itself so contract-token rows are never grouped under a null asset_code.

{% enddocs %}
