[comment]: < History Assets -

{% docs history_assets_staging %}
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

{% docs asset_type %}
The identifier for type of asset code, can be a alphanumeric with 4 characters, 12 characters or the native asset to the network, XLM.

- Natural Key
- Required
- Cluster Field

#### Notes:
XLM is the native asset to the network. XLM has no asset code or issuer representation and will instead be displayed with an asset type of 'native'
{% enddocs %}

{% docs asset_code %}
The 4 or 12 character code representation of the asset on the network

- Natural Key
- Cluster Field

#### Notes:
Asset codes have no guarantees of uniqueness. The combination of asset code, issuer and type represents a distinct asset
{% enddocs %}

{% docs asset_issuer %}
The account address of the original asset issuer that created the asset

- Natural Key
- Cluster Field
{% enddocs %}