[comment]: < Liquidity Pools Current -

{% docs liquidity_pools_current %}

The `liquidity_pools_current` table is a nightly snapshotted table that represents the current status of all liquidity pools. The table returns the latest pool entry, which is defined as the highest `last_modified_ledger` per liquidity pool on the Stellar Network. Deleted pools are included in the table. For full state history, please use the `liquidity_pools` table.

**The `liquidity_pools_current` table is only updated nightly. Intraday ledger state changes are not captured in the table.**

{% enddocs %}

{% docs asset_pair %}

A concatenated representation of the pair of assets in the liquidity pool, in the form `asset_a_code:asset_b_code`. In the case when the pool contains `XLM`, `XLM` is written as an asset code even though the native asset normally has a null asset code. Asset pair intends to make a human readable name for a pool, but does **not** represent a unique pool id. Different asset issuers can mint asset codes of the same name. In these cases, there will be duplicate `asset_pair` names. The pool ids are unique.

{% enddocs %}
