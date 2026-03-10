[comment]: < Ledger Fee Stats -

{% docs ledger_fee_stats %}

Ledger-grain fee statistics for the Stellar network, splitting transactions into Classic and Soroban categories. Aggregates fee fields per ledger to support fee analysis, surge pricing detection, and resource cost monitoring. Soroban transactions have resource_fee > 0; Classic transactions have resource_fee = 0.

{% enddocs %}

{% docs ledger_fee_day_agg %}

Day when the ledger fee stats were aggregated.

{% enddocs %}

{% docs ledger_fee_ledger_sequence %}

The unique ledger sequence number. This is the grain of the table -- one row per ledger.

{% enddocs %}

{% docs ledger_fee_total_fee_charged %}

Sum of fee_charged across all transactions (Classic + Soroban) in the ledger. This is the total fees actually paid.

{% enddocs %}

{% docs ledger_fee_max_fee_charged %}

Maximum fee_charged across all transactions (Classic + Soroban) in the ledger.

{% enddocs %}

{% docs ledger_fee_txn_count %}

Total number of transactions (Classic + Soroban) in the ledger.

{% enddocs %}

{% docs ledger_fee_total_effective_txn_operation_count %}

Total number of effective operations across all transactions (Classic + Soroban) in the ledger. Uses effective_txn_operation_count, which adds 1 to the operation count for fee-bump transactions (where new_max_fee is not null) to account for the extra inner transaction. This is the same denominator used when calculating per-operation fee metrics.

{% enddocs %}

{% docs ledger_fee_classic_txn_count %}

Number of Classic transactions in the ledger. Classic transactions have resource_fee = 0.

{% enddocs %}

{% docs ledger_fee_classic_total_effective_operation_count %}

Total number of effective operations across Classic transactions in the ledger. Uses effective_txn_operation_count, which adds 1 for fee-bump transactions. This is the same denominator used in classic_max_inclusion_fee_per_op and classic_min_inclusion_fee_per_op.

{% enddocs %}

{% docs ledger_fee_classic_sum_fee_charged %}

Sum of fee_charged across Classic transactions. For Classic txns, fee_charged is the inclusion fee (no resource_fee component).

{% enddocs %}

{% docs ledger_fee_classic_max_fee_charged %}

Maximum fee_charged across Classic transactions in the ledger.

{% enddocs %}

{% docs ledger_fee_classic_sum_max_fee %}

Sum of COALESCE(new_max_fee, max_fee) across Classic transactions. Represents total willingness-to-pay.

{% enddocs %}

{% docs ledger_fee_classic_max_max_fee %}

Maximum of COALESCE(new_max_fee, max_fee) across Classic transactions in the ledger.

{% enddocs %}

{% docs ledger_fee_classic_max_inclusion_fee_per_op %}

Maximum inclusion fee per operation (fee_charged / effective_txn_operation_count) across Classic transactions. Fee-bump txns add 1 to the operation count.

{% enddocs %}

{% docs ledger_fee_classic_min_inclusion_fee_per_op %}

Minimum inclusion fee per operation across Classic transactions in the ledger.

{% enddocs %}

{% docs ledger_fee_classic_surge_txn_count %}

Number of Classic transactions in the ledger where fee_charged exceeded the base fee (100 stroops per operation), indicating surge pricing.

{% enddocs %}

{% docs ledger_fee_classic_surge_operation_count %}

Total operations in Classic transactions that experienced surge pricing in the ledger.

{% enddocs %}

{% docs ledger_fee_classic_is_surge_ledger %}

Boolean flag: true if any Classic transaction in the ledger experienced surge pricing.

{% enddocs %}

{% docs ledger_fee_soroban_txn_count %}

Number of Soroban transactions in the ledger. Soroban transactions have resource_fee > 0.

{% enddocs %}

{% docs ledger_fee_soroban_total_effective_operation_count %}

Total number of effective operations across Soroban transactions in the ledger. Uses effective_txn_operation_count, which adds 1 for fee-bump transactions. This is the same denominator used in soroban_max_inclusion_fee_per_op and soroban_min_inclusion_fee_per_op.

{% enddocs %}

{% docs ledger_fee_soroban_sum_fee_charged %}

Sum of fee_charged across Soroban transactions. fee_charged = inclusion_fee_charged + non_refundable_resource_fee_charged + refundable_resource_fee_charged.

{% enddocs %}

{% docs ledger_fee_soroban_max_fee_charged %}

Maximum fee_charged across Soroban transactions in the ledger.

{% enddocs %}

{% docs ledger_fee_soroban_sum_inclusion_fee_charged %}

Sum of inclusion_fee_charged across Soroban transactions. During normal conditions this is 100 stroops per txn (200 for fee bumps). Higher during surge pricing.

{% enddocs %}

{% docs ledger_fee_soroban_max_inclusion_fee_charged %}

Maximum inclusion_fee_charged across Soroban transactions in the ledger.

{% enddocs %}

{% docs ledger_fee_soroban_sum_inclusion_fee_bid %}

Sum of inclusion_fee_bid across Soroban transactions. inclusion_fee_bid = COALESCE(new_max_fee, max_fee) - resource_fee.

{% enddocs %}

{% docs ledger_fee_soroban_max_inclusion_fee_bid %}

Maximum inclusion_fee_bid across Soroban transactions in the ledger.

{% enddocs %}

{% docs ledger_fee_soroban_max_inclusion_fee_per_op %}

Maximum inclusion fee per operation (inclusion_fee_charged / effective_txn_operation_count) across Soroban transactions in the ledger.

{% enddocs %}

{% docs ledger_fee_soroban_min_inclusion_fee_per_op %}

Minimum inclusion fee per operation across Soroban transactions in the ledger.

{% enddocs %}

{% docs ledger_fee_soroban_sum_resource_fee %}

Sum of resource_fee (the pre-execution budget for Soroban resource consumption) across Soroban transactions in the ledger.

{% enddocs %}

{% docs ledger_fee_soroban_max_resource_fee %}

Maximum resource_fee across Soroban transactions in the ledger.

{% enddocs %}

{% docs ledger_fee_soroban_min_resource_fee %}

Minimum resource_fee across Soroban transactions in the ledger.

{% enddocs %}

{% docs ledger_fee_soroban_sum_non_refundable_resource_fee_charged %}

Sum of non_refundable_resource_fee_charged across Soroban transactions. Covers CPU instructions, read bytes, write bytes, and bandwidth. Charged based on declared resources regardless of tx success/failure.

{% enddocs %}

{% docs ledger_fee_soroban_max_non_refundable_resource_fee_charged %}

Maximum non_refundable_resource_fee_charged across Soroban transactions in the ledger.

{% enddocs %}

{% docs ledger_fee_soroban_min_non_refundable_resource_fee_charged %}

Minimum non_refundable_resource_fee_charged across Soroban transactions in the ledger.

{% enddocs %}

{% docs ledger_fee_soroban_sum_refundable_resource_fee_charged %}

Sum of refundable_resource_fee_charged across Soroban transactions. Covers rent, events, and return value. Based on actual usage; 0 for failed transactions.

{% enddocs %}

{% docs ledger_fee_soroban_max_refundable_resource_fee_charged %}

Maximum refundable_resource_fee_charged across Soroban transactions in the ledger.

{% enddocs %}

{% docs ledger_fee_soroban_min_refundable_resource_fee_charged %}

Minimum refundable_resource_fee_charged across Soroban transactions in the ledger.

{% enddocs %}

{% docs ledger_fee_soroban_sum_resource_fee_refund %}

Sum of resource_fee_refund across Soroban transactions. NOTE: Currently broken -- always 0. Should be: resource_fee - non_refundable_resource_fee_charged - refundable_resource_fee_charged.

{% enddocs %}

{% docs ledger_fee_soroban_max_resource_fee_refund %}

Maximum resource_fee_refund across Soroban transactions. NOTE: Currently broken -- always 0.

{% enddocs %}

{% docs ledger_fee_soroban_min_resource_fee_refund %}

Minimum resource_fee_refund across Soroban transactions. NOTE: Currently broken -- always 0.

{% enddocs %}

{% docs ledger_fee_soroban_sum_rent_fee_charged %}

Sum of rent_fee_charged across Soroban transactions. This is the portion of refundable_resource_fee_charged that went to ledger entry TTL extensions.

{% enddocs %}

{% docs ledger_fee_soroban_max_rent_fee_charged %}

Maximum rent_fee_charged across Soroban transactions in the ledger.

{% enddocs %}

{% docs ledger_fee_soroban_min_rent_fee_charged %}

Minimum rent_fee_charged across Soroban transactions in the ledger. Will be 0 for ledgers where all Soroban transactions failed, as rent is not charged on failed transactions.

{% enddocs %}

{% docs ledger_fee_soroban_surge_txn_count %}

Number of Soroban transactions in the ledger where inclusion_fee_charged exceeded the base fee (100 stroops per operation), indicating surge pricing.

{% enddocs %}

{% docs ledger_fee_soroban_surge_operation_count %}

Total operations in Soroban transactions that experienced surge pricing in the ledger.

{% enddocs %}

{% docs ledger_fee_soroban_is_surge_ledger %}

Boolean flag: true if any Soroban transaction in the ledger experienced surge pricing.

{% enddocs %}

{% docs ledger_fee_closed_at %}

Timestamp in UTC when the ledger closed and was committed to the network. Sourced from history_ledgers. Enables sub-daily time filtering (e.g. hourly aggregations) without requiring a join back to history_ledgers.

{% enddocs %}

{% docs ledger_fee_fee_pool %}

The total fee pool for the ledger, sourced from history_ledgers.

{% enddocs %}

{% docs ledger_fee_airflow_start_ts %}

Timestamp when the Airflow DAG run started. Used for pipeline metadata and debugging.

{% enddocs %}
