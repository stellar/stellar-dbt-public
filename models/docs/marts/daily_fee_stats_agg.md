[comment]: < Daily Fee Stats -

{% docs daily_fee_stats %}

Daily aggregation of ledger-grain fee statistics from `ledger_fee_stats_agg`. Rolls up ledger-level fee metrics to day grain, splitting transactions into Classic and Soroban categories. Includes surge pricing percentages and weighted-average inclusion fees per operation.

{% enddocs %}

{% docs daily_fee_min_ledger_sequence %}

First (minimum) ledger sequence number for the day.

{% enddocs %}

{% docs daily_fee_max_ledger_sequence %}

Last (maximum) ledger sequence number for the day.

{% enddocs %}

{% docs daily_fee_total_ledgers %}

Total number of ledgers processed for the day, regardless of whether they contain Classic or Soroban transactions. Used as the denominator for `total_pct_ledgers_in_surge`.

{% enddocs %}

{% docs daily_fee_classic_total_ledgers %}

Total number of ledgers containing at least one Classic transaction for the day.

{% enddocs %}

{% docs daily_fee_classic_surge_ledger_count %}

Number of ledgers where at least one Classic transaction experienced surge pricing for the day.

{% enddocs %}

{% docs daily_fee_classic_total_surge_txn_count %}

Total number of Classic transactions that experienced surge pricing across all ledgers for the day.

{% enddocs %}

{% docs daily_fee_classic_total_surge_operation_count %}

Total operations in Classic transactions that experienced surge pricing across all ledgers for the day.

{% enddocs %}

{% docs daily_fee_classic_pct_ledgers_in_surge %}

Percentage of Classic-containing ledgers that experienced surge pricing for the day. Calculated as 100 * classic_surge_ledger_count / classic_total_ledgers.

{% enddocs %}

{% docs daily_fee_soroban_total_ledgers %}

Total number of ledgers containing at least one Soroban transaction for the day.

{% enddocs %}

{% docs daily_fee_soroban_surge_ledger_count %}

Number of ledgers where at least one Soroban transaction experienced surge pricing for the day.

{% enddocs %}

{% docs daily_fee_soroban_total_surge_txn_count %}

Total number of Soroban transactions that experienced surge pricing across all ledgers for the day.

{% enddocs %}

{% docs daily_fee_soroban_total_surge_operation_count %}

Total operations in Soroban transactions that experienced surge pricing across all ledgers for the day.

{% enddocs %}

{% docs daily_fee_soroban_pct_ledgers_in_surge %}

Percentage of Soroban-containing ledgers that experienced surge pricing for the day. Calculated as 100 * soroban_surge_ledger_count / soroban_total_ledgers.

{% enddocs %}

{% docs daily_fee_total_pct_ledgers_in_surge %}

Percentage of all ledgers for the day where at least one transaction (Classic or Soroban) experienced surge pricing. Calculated as 100 * count(ledgers where classic_is_surge_ledger or soroban_is_surge_ledger) / total ledgers.

{% enddocs %}

{% docs daily_fee_fee_pool %}

The cumulative fee pool balance (in stroops) at the end of the day, taken from the last ledger that closed on that day. The fee pool is a protocol-level accumulator in the ledger header that tracks all transaction fees ever collected by the network. Since inflation was disabled in Protocol 12 (October 2019), no mechanism exists to withdraw from the fee pool, so this value is monotonically increasing. To see daily fees collected, use total_fee_charged instead.

{% enddocs %}
