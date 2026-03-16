[comment]: < Hourly Fee Agg Account -

{% docs hourly_fee_agg_account %}

Hourly fee aggregation by fee account, sourced from `stg_history_transactions`. Provides attribution of fee activity to individual accounts across both Classic and Soroban transaction lanes. Designed to support incident investigation (e.g. identifying which accounts are driving surge pricing) at sub-daily granularity.

One row per (hour, fee_account).

{% enddocs %}

{% docs hourly_fee_agg_hour_agg %}

Hour-truncated UTC timestamp of the aggregation window. Derived from `timestamp_trunc(closed_at, hour)`.

{% enddocs %}

{% docs hourly_fee_agg_fee_account %}

The account that paid the transaction fee. For fee-bump transactions, this is the fee sponsor (not the transaction source account). For non-fee-bump transactions, this is the transaction source account.

{% enddocs %}

{% docs hourly_fee_agg_txn_count %}

Total number of transactions (Classic + Soroban) submitted by this fee account in the hour.

{% enddocs %}

{% docs hourly_fee_agg_failed_txn_count %}

Number of failed transactions (Classic + Soroban) for this fee account in the hour. Failed transactions are still charged fees and included in all fee aggregates.

{% enddocs %}

{% docs hourly_fee_agg_total_fee_charged %}

Sum of fee_charged across all transactions (Classic + Soroban) for this fee account in the hour. This is the total fees actually paid.

{% enddocs %}

{% docs hourly_fee_agg_total_max_fee %}

Sum of max_fee across all transactions for this fee account in the hour. Represents total willingness-to-pay.

{% enddocs %}

{% docs hourly_fee_agg_fee_efficiency %}

Ratio of total_fee_charged to total_max_fee. Values closer to 1.0 indicate the account is bidding close to what it actually pays; lower values indicate overbidding.

{% enddocs %}

{% docs hourly_fee_agg_total_effective_operation_count %}

Total effective operations across all transactions for this fee account. Adds 1 to the operation count for fee-bump transactions (where new_max_fee is not null).

{% enddocs %}

{% docs hourly_fee_agg_total_raw_operation_count %}

Total raw operations (txn_operation_count) across all transactions for this fee account. Does NOT include fee-bump adjustment.

{% enddocs %}

{% docs hourly_fee_agg_classic_txn_count %}

Number of Classic transactions for this fee account in the hour. Classic transactions have resource_fee = 0.

{% enddocs %}

{% docs hourly_fee_agg_classic_failed_txn_count %}

Number of failed Classic transactions for this fee account in the hour.

{% enddocs %}

{% docs hourly_fee_agg_classic_total_fee_charged %}

Sum of fee_charged across Classic transactions for this fee account. For Classic txns, fee_charged is the inclusion fee (no resource_fee component).

{% enddocs %}

{% docs hourly_fee_agg_classic_total_max_fee %}

Sum of max_fee across Classic transactions for this fee account. Represents Classic willingness-to-pay.

{% enddocs %}

{% docs hourly_fee_agg_classic_total_effective_operation_count %}

Total effective operations across Classic transactions for this fee account. Adds 1 for fee-bump transactions.

{% enddocs %}

{% docs hourly_fee_agg_soroban_txn_count %}

Number of Soroban transactions for this fee account in the hour. Soroban transactions have resource_fee > 0.

{% enddocs %}

{% docs hourly_fee_agg_soroban_failed_txn_count %}

Number of failed Soroban transactions for this fee account in the hour. Even failed Soroban transactions are charged inclusion_fee_charged and non_refundable_resource_fee_charged.

{% enddocs %}

{% docs hourly_fee_agg_soroban_total_fee_charged %}

Sum of fee_charged across Soroban transactions for this fee account. fee_charged = inclusion_fee_charged + non_refundable_resource_fee_charged + refundable_resource_fee_charged - resource_fee_refund.

{% enddocs %}

{% docs hourly_fee_agg_soroban_total_inclusion_fee_charged %}

Sum of inclusion_fee_charged across Soroban transactions for this fee account.

{% enddocs %}

{% docs hourly_fee_agg_soroban_total_inclusion_fee_bid %}

Sum of inclusion_fee_bid across Soroban transactions for this fee account. Represents total willingness-to-pay for inclusion.

{% enddocs %}

{% docs hourly_fee_agg_soroban_total_resource_fee %}

Sum of resource_fee (pre-execution budget) across Soroban transactions for this fee account.

{% enddocs %}

{% docs hourly_fee_agg_soroban_total_non_refundable_resource_fee %}

Sum of non_refundable_resource_fee_charged across Soroban transactions. Covers CPU instructions, read bytes, write bytes, and bandwidth. Charged regardless of tx success/failure.

{% enddocs %}

{% docs hourly_fee_agg_soroban_total_refundable_resource_fee %}

Sum of refundable_resource_fee_charged across Soroban transactions. Covers rent, events, and return value. Based on actual usage; 0 for failed transactions.

{% enddocs %}

{% docs hourly_fee_agg_soroban_total_rent_fee %}

Sum of rent_fee_charged across Soroban transactions. The portion of refundable_resource_fee_charged that went to ledger entry TTL extensions.

{% enddocs %}

{% docs hourly_fee_agg_soroban_total_resource_fee_refund %}

Sum of resource_fee_refund across Soroban transactions. NOTE: Currently broken upstream -- always 0.

{% enddocs %}

{% docs hourly_fee_agg_soroban_total_effective_operation_count %}

Total effective operations across Soroban transactions for this fee account. Adds 1 for fee-bump transactions.

{% enddocs %}
