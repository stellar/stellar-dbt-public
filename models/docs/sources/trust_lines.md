[comment]: < Trust_lines -

{% docs trust_lines %}
Trustlines track authorized and deleted lines of trust between an account and assets. This table can be viewed as a subentry to an account because all trustlines must be associated with a single account. The trust line also tracks the balance of the asset held by the account and any buying or selling liabilities on the orderbook for a given account and asset. You do not have to hold a balance of an asset to trust the asset. 
{% enddocs %}

{% docs ledger_key %}
The unique ledger key when the trust line state last changed.

- Natural Key
- Required Field
{% enddocs %}


{% docs trust_balance %}
The number of units of an asset held by this account.

- Required Field
{% enddocs %}

{% docs trust_line_limit %}
The maximum amount of this asset that this account is willing to accept. The limit is specified when opening a trust line.

- Required Field
{% enddocs %}
