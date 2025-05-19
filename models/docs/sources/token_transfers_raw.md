[comment]: < Token Transfers Raw -

{% docs token_transfers_raw %}
The token transfers raw table contains the SEP-41 compliant event stream from the token transfer processor. This table's purpose is to track the token value movement on the stellar network in the form of `transfer`, `mint`, `burn`, `clawback`, and `fee` events.

Note that the events within this table are a subset of the events in the history_contract_events table.
{% enddocs %}

{% docs event_topic %}
The SEP-41 topic for the event defining the token transfer value movement type. Valid values are `transfer`, `mint`, `burn`, `clawback`, and `fee`.
{% enddocs %}

{% docs asset %}
The concatentation of asset information into `asset_type:asset_code:asset_issuer`

Note: the value of this field for XLM is `native`
{% enddocs %}

{% docs from %}
The source address for the token transfer event amount
{% enddocs %}

{% docs to %}
The destination address for the token transfer event amount
{% enddocs %}

{% docs amount_float %}
The normalized float amount of the asset. This is equivalent to `raw stroop amount of asset * 0.0000001`
{% enddocs %}

{% docs amount_raw %}
The raw stroop amount of the asset
{% enddocs %}

{% docs to_muxed %}
The multiplexed strkey representation of the `to` address.
{% enddocs %}

{% docs to_muxed_id %}
The multiplexed ID used to generate the multiplexed strkey representation of the `to` address.
{% enddocs %}
