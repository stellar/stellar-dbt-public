[comment]: < Token Transfer Fact -

{% docs token_asset %}
The string concatenation of (asset_type, asset_code, asset_issuer). The value of this is 'native' for the native asset/XLM.
{% enddocs %}

{% docs token_amount %}
The float amount of the token calculated by the amount_raw/10^7.
{% enddocs %}

{% docs token_amount_raw %}
The raw number of stroops (smallest non-zero amount unit) of the token. A single stroop is 10^-7 of a single token.
Note that the data type for this is string.
{% enddocs %}

{% docs event_operation_type %}
The operation type that caused the event to be emitted. Check [hubble-docs](https://developers.stellar.org/docs/data/analytics/hubble/data-catalog/data-dictionary/history-operations#column-details) to get list of operation types.

{% enddocs %}

{% docs is_soroban %}
This denotes whether the event executed out of the classic or smart contract environment.
{% enddocs %}

{% docs token_unique_key %}
The sha256 of the concatenation of transaction_hash, operation_id, contract_id, to, from, and asset for token transfer events
{% enddocs %}
