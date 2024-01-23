[comment]: < History Assets -

{% docs history_assets %}
Table reports which assets are used during the batch interval, which can help identify periods of time of large activity for an asset. The table **does not** have a primary key and assets are duplicated in the table as they are used during different periods of time. To get a distinct count of assets on the network, please refer to the history_assets table. Table not widely used.
{% enddocs %}

{% docs history_assets %}
Table contains every unique asset of the network, where the batch_run_date can be used as a proxy for when the asset was first created.
{% enddocs %}

{% docs assets_id %}
Unique identifier for the asset code, type and issuer combination. This is not a primary key on the table

- Natural Key
- Required

{% enddocs %}
