[comment]: < History effects -

{% docs history_effects %}
The history effects table stores detailed information effect. Effects represent specific changes that occur in the ledger as a result of successful operations, but are not necessarily directly reflected in the ledger or history, as transactions and operations are.
{% enddocs %}

{% docs details_effects %}
Record that contains details based on the type of effect. Each effect will return its own relevant details, with the rest of the details as null
{% enddocs %}

{% docs details_liquidity_pool %}
Liquidity pools provide a simple, non-interactive way to trade large amounts of capital and enable high volumes of trading
{% enddocs %}

{% docs details_liquidity_pool_fee_bp %}
The number of basis points charged as a percentage of the trade in order to complete the transaction. The fees earned on all trades are divided amongst pool shareholders and distributed as an incentive to keep money in the pools
{% enddocs %}

{% docs details_liquidity_pool_total_shares %}
Total number of pool shares issued
{% enddocs %}

{% docs details_liquidity_pool_total_trustlines %}
Number of trustlines for the associated pool shares
{% enddocs %}

{% docs details_liquidity_pool_type %}
The mechanism that calculates pricing and division of shares for the pool. With the initial AMM rollout, the only type of liquidity pool allowed to be created is a constant product pool.
{% enddocs %}

{% docs details_liquidity_pool_reserves %}
Reserved asset in liquidity pool. Reported in the format {asset: "asset_code:asset_issuer", amount: Number}
{% enddocs %}

{% docs details_reserves_received %}
Asset amount received for reserves from liquidity pool withdraw. Reported in the format {asset: "asset_code:asset_issuer", amount: Number}
{% enddocs %}

{% docs details_reserves_deposited %}
Asset amount deposited for reserves from liquidity pool deposit. Reported in the format {asset: "asset_code:asset_issuer", amount: Number}
{% enddocs %}

{% docs details_reserves_revoked %}
Asset amount revoked for reserves from liquidity pool revoke. Reported in the format {asset: "asset_code:asset_issuer", amount: Number}
{% enddocs %}

{% docs details_reserves_revoked_claimable_balance_id %}
Claimable balance id
{% enddocs %}

{% docs details_bought %}
Asset bought from trade. Reported in the format {asset: "asset_code:asset_issuer", amount: Number}
{% enddocs %}

{% docs details_sold %}
Asset sold from trade. Reported in the format {asset: "asset_code:asset_issuer", amount: Number}
{% enddocs %}

{% docs details_shares_revoked %}
Shares revoked from liquidity pool revoke
{% enddocs %}

{% docs details_shares_redeemed %}
Shares redeemed from liquidity pool withrdaw
{% enddocs %}

{% docs details_new_seq %}
New sequence number after bump sequence
{% enddocs %}

{% docs details_inflation_destination %}
Inflation destination account id
{% enddocs %}

{% docs details_authorized_flag %}
Auth value for set trustline flags
{% enddocs %}

{% docs details_auth_immutable_flag %}
Auth value for set trustline flags
{% enddocs %}

{% docs details_authorized_to_maintain_liabilites %}
Auth value for set trustline flags
{% enddocs %}

{% docs details_auth_revocable_flag %}
Auth value for set trustline flags
{% enddocs %}

{% docs details_auth_required_flag %}
Auth value for set trustline flags
{% enddocs %}

{% docs details_auth_clawback_enabled_flag %}
Auth value for set trustline flags
{% enddocs %}

{% docs details_claimable_balance_clawback_enabled_flag %}
Auth value for set trustline flags
{% enddocs %}

{% docs details_clawback_enabled_flag %}
Auth value for set trustline flags
{% enddocs %}

{% docs details_signer %}
The address of the account that is allowed to authorize (sign) transactions for another account. This process is called multi-sig
{% enddocs %}

{% docs details_new_sponsor %}
The new account address of the sponsor who is paying the reserves for this signer
{% enddocs %}

{% docs details_former_sponsor %}
The former account address of the sponsor who is paying the reserves for this signer
{% enddocs %}

{% docs details_weight %}
Signer weight
{% enddocs %}

{% docs details_public_key %}
Signer public key
{% enddocs %}

{% docs details_seller %}
Selling account
{% enddocs %}

{% docs details_seller_muxed %}
Account multiplexed
{% enddocs %}

{% docs details_seller_muxed_id %}
Account multiplexed id
{% enddocs %}

{% docs contract_event_type %}
Soroban contract invoke host function event type: transfer, mint, clawback, or burn
{% enddocs %}

{% docs details_entries %}
Soroban ledger change entries related to contract extension
{% enddocs %}
