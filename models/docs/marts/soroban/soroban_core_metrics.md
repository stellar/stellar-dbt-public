[comment]: < Soroban Core Metrics -

{% docs soroban_core_metrics %}

Pre-parsed and flattened core_metrics contract events from Soroban. Each row represents a single metric emitted by a core_metrics diagnostic event, enabling efficient network utilization calculations without full table scans and JSON parsing of the raw `history_contract_events` table.

This model extracts the metric key and value from the JSON-encoded topics and data fields of contract events where the first topic symbol is `core_metrics` and the event type is diagnostic (`type = 2`).

{% enddocs %}

{% docs metric_key %}

The name of the core metric emitted by the Soroban contract event (e.g., cpu_insn, mem_byte, read_entry, write_entry, ledger_read_byte, ledger_write_byte, emit_event_byte).

{% enddocs %}

{% docs metric_value %}

The numeric value of the core metric, representing resource consumption for the associated transaction.

{% enddocs %}
