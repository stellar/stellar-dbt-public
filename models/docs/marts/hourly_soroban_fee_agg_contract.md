[comment]: # (Hourly Soroban Fee Agg Contract)

{% docs hourly_soroban_fee_agg_contract %}

Hourly fee aggregation by contract, sourced from `enriched_history_operations_soroban`. Soroban-only by nature since contract_id only exists on Soroban operations. Provides attribution of fee activity to individual smart contracts, enabling identification of which contracts are driving fee volume or surge pricing.

Soroban operations without a contract_id (e.g. WASM uploads) are excluded. Deduplicated to transaction grain to prevent double-counting fees if Soroban transactions support multiple operations in the future.

One row per (hour, contract_id).

{% enddocs %}

{% docs hourly_soroban_fee_agg_hour_agg %}

Hour-truncated UTC timestamp of the aggregation window. Derived from `timestamp_trunc(closed_at, hour)`.

{% enddocs %}

{% docs hourly_soroban_fee_agg_contract_id %}

The Soroban smart contract address invoked by the transaction.

{% enddocs %}

{% docs hourly_soroban_fee_agg_txn_count %}

Total number of Soroban transactions invoking this contract in the hour.

{% enddocs %}

{% docs hourly_soroban_fee_agg_failed_txn_count %}

Number of failed Soroban transactions for this contract in the hour. Failed transactions are still charged inclusion_fee_charged and non_refundable_resource_fee_charged.

{% enddocs %}

{% docs hourly_soroban_fee_agg_unique_fee_source_accounts %}

Count of distinct fee-paying accounts for this contract in the hour, derived as `count(distinct coalesce(fee_account, txn_account))`. For fee-bump transactions this is the fee sponsor; for regular transactions this is the transaction originator. Useful for distinguishing between a single account driving a contract's fee volume vs. broad usage.

{% enddocs %}

{% docs hourly_soroban_fee_agg_total_fee_charged %}

Sum of fee_charged across all transactions invoking this contract in the hour.

{% enddocs %}

{% docs hourly_soroban_fee_agg_avg_fee_charged %}

Average fee_charged per transaction invoking this contract in the hour.

{% enddocs %}

{% docs hourly_soroban_fee_agg_max_fee_charged %}

Maximum fee_charged across transactions invoking this contract in the hour.

{% enddocs %}

{% docs hourly_soroban_fee_agg_total_max_fee %}

Sum of the effective fee ceiling — `coalesce(new_max_fee, max_fee)` — across transactions invoking this contract. For fee-bump transactions, `new_max_fee` is the actual ceiling used by the network; `max_fee` is the inner transaction's original max and is not the binding constraint. Represents total willingness-to-pay.

{% enddocs %}

{% docs hourly_soroban_fee_agg_fee_efficiency %}

Ratio of total_fee_charged to total_max_fee (where total_max_fee uses the effective ceiling via `coalesce(new_max_fee, max_fee)`). Bounded (0, 1]. Values closer to 1.0 indicate callers are bidding close to what they actually pay; lower values indicate overbidding.

{% enddocs %}

{% docs hourly_soroban_fee_agg_total_inclusion_fee_charged %}

Sum of inclusion_fee_charged across transactions invoking this contract.

{% enddocs %}

{% docs hourly_soroban_fee_agg_avg_inclusion_fee_charged %}

Average inclusion_fee_charged per transaction invoking this contract.

{% enddocs %}

{% docs hourly_soroban_fee_agg_total_inclusion_fee_bid %}

Sum of inclusion_fee_bid across transactions invoking this contract. Represents total willingness-to-pay for inclusion.

{% enddocs %}

{% docs hourly_soroban_fee_agg_total_resource_fee %}

Sum of resource_fee (pre-execution budget) across transactions invoking this contract.

{% enddocs %}

{% docs hourly_soroban_fee_agg_avg_resource_fee %}

Average resource_fee per transaction invoking this contract.

{% enddocs %}

{% docs hourly_soroban_fee_agg_total_non_refundable_resource_fee %}

Sum of non_refundable_resource_fee_charged across transactions. Covers CPU instructions, read bytes, write bytes, and bandwidth. Charged regardless of tx success/failure.

{% enddocs %}

{% docs hourly_soroban_fee_agg_total_refundable_resource_fee %}

Sum of refundable_resource_fee_charged across transactions. Covers rent, events, and return value. Based on actual usage; 0 for failed transactions.

{% enddocs %}

{% docs hourly_soroban_fee_agg_total_rent_fee %}

Sum of rent_fee_charged across transactions. The portion of refundable_resource_fee_charged that went to ledger entry TTL extensions.

{% enddocs %}

{% docs hourly_soroban_fee_agg_surge_txn_count %}

Number of Soroban transactions for this contract where inclusion_fee_charged exceeded the base fee (effective_operation_count * 100 stroops). During normal conditions the network charges exactly the base fee regardless of bid, so a higher charge indicates the transaction was included in a surge-priced ledger.

{% enddocs %}

{% docs hourly_soroban_fee_agg_total_resource_fee_refund %}

Sum of resource_fee_refund across transactions. Represents the unused portion of resource_fee returned to the account after execution.

{% enddocs %}
