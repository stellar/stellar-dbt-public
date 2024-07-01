[comment]: < Liquidity Pools -

{% docs liquidity_pools %}
Stellar rolled out Automated Market Makers to its network in Nov 2021, which improves liquidity between asset pairs while incentivizing users to stake money in pools.
Liquidity pools provide a simple, non-interactive way to trade large amounts of capital and enable high volumes of trading. Liquidity pools can be created between asset pairs and algorithmically controls the supply of the assets to give the best exchange rate while not requiring an orderbook in order to execute the trade. For each trade executed through a liquidity pool, the users with staked liquidity in the pool earn fees, which are distributed automatically to their accounts. Users can deposit and withdraw money in the pools; trades only execute via path payment operation.
{% enddocs %}

{% docs liquidity_pool_id %}
Unique identifier for a liquidity pool. There cannot be duplicate pools for the same asset pair. Once a pool has been created for the asset pair, another cannot be created.

- Natural Key
- Cluster Field
- Required Field

#### Notes:

There is a good primer on AMMs [here](https://developers.stellar.org/docs/glossary/liquidity-pool?q=glossary+liquidity+pool).
{% enddocs %}

{% docs pool_type%}
The mechanism that calculates pricing and division of shares for the pool. With the initial AMM rollout, the only type of liquidity pool allowed to be created is a constant product pool.

- Required Field

#### Notes:

For more information regarding pricing and deposit calculations, read [Cap-38](https://github.com/stellar/stellar-protocol/blob/master/core/cap-0038.md).

| Default Value    |
| ---------------- |
| constant_product |

{% enddocs %}

{% docs fee %}
The number of basis points charged as a percentage of the trade in order to complete the transaction. The fees earned on all trades are divided amongst pool shareholders and distributed as an incentive to keep money in the pools

- Required Field

#### Notes:

Fees are distributed immediately to accounts as the transaction completes. There is no schedule for fee distribution

| Default Value |
| ------------- |
| 30            |

{% enddocs %}

{% docs trustline_count %}
Total number of accounts with trustlines authorized to the pool. To create a trustline, an account must trust both base assets before trusting a pool with the asset pair.

- Required Field

#### Notes:

If the issuer of A or B revokes authorization on the trustline, the account will automatically withdraw from every liquidity pool containing that asset and those pool trustlines will be deleted.
{% enddocs %}

{% docs pool_share_count %}
Participation in a liquidity pool is represented by a pool share.
The total number of pool shares is calculated by a constant product formula and is an arbitrary number representing the amount of participation in the pool.

- Required Field

#### Notes:

Shares are not transferable; the only way to increase the number of pool shares held is to deposit into a liquidity pool. Conversely, decreasing pools shares can only be accomplished through a withdraw operation. Shares cannot be sent in payments or sold using offers.
{% enddocs %}

{% docs asset_a_id %}
The Farm Hash encoding of the Asset Code + Asset Issuer and Asset Type for one of the asset pairs in a liquidity pool.

{% enddocs %}

{% docs asset_a_amount %}
The raw number of tokens locked in the pool for one of the two asset pairs in the liquidity pool.

- Required Field
  {% enddocs %}

{% docs asset_b_id %}
The Farm Hash encoding of the Asset Code + Asset Issuer and Asset Type for the corresponding asset in the liquidity pool.

{% enddocs %}

{% docs asset_b_amount %}
The raw number of tokens locked in the pool for one of the two asset pairs in the liquidity pool.

- Required Field
  {% enddocs %}
