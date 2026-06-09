{% docs soroban_core_metrics %}

Denormalized Soroban host-emitted `core_metrics` diagnostic events extracted from `history_contract_events` and joined to the root contract from each transaction's `invoke_host_function` operation. One row per
`(transaction_hash, metric_key)`.

The Soroban host emits 19 core_metrics events at the end of every transaction summarizing the resources consumed by the invocation: CPU instructions, memory bytes, ledger entries read/written, event emission,
invocation time, and per-category read/write/key/code byte counters. These events live inside JSON columns (`topics_decoded`, `data_decoded`) on `history_contract_events`, which makes them expensive to query at
scale — dashboards that previously parsed JSON for every query now read pre-extracted INT64 columns from this mart.

`contract_id` is sourced via LEFT JOIN to `enriched_history_operations_soroban` filtered to `invoke_host_function` ops (`op_type = 24`) with a populated, non-empty `contract_id`. Rows where the join misses
(~0.001% of rows) are kept with `contract_id = NULL`; these correspond to:

* `invoke_host_function` with sub-type `upload_wasm` — no contract exists yet; the uploaded artifact is a `ContractCode` entry identified by its Wasm hash.
* `extend_footprint_ttl` / `restore_footprint` transactions with no accompanying `invoke_host_function` op.

Includes both successful and failed Soroban transactions, since the host emits core_metrics regardless of outcome and fees are charged on failed invocations.

Partitioned by `closed_at` (daily), clustered by `contract_id`. Backfilled from 2024-02-20 (Soroban launch).

{% enddocs %}

{% docs soroban_core_metrics_closed_at %}

Timestamp the ledger that included this transaction was closed by the Stellar network. Partition key for the table.

{% enddocs %}

{% docs soroban_core_metrics_ledger_sequence %}

Sequence number of the ledger that included this transaction. Allows ledger-grain analysis (e.g., aggregating metric_value per ledger to compute per-ledger resource utilization against the protocol's
ledger-level limits).

{% enddocs %}

{% docs soroban_core_metrics_transaction_hash %}

Hex hash of the Soroban transaction that produced this metric. Combined with `metric_key`, forms the table's unique grain (one row per metric per transaction).

{% enddocs %}

{% docs soroban_core_metrics_contract_id %}

The Soroban smart contract address (strkey `C...`) invoked at the root of this transaction's `invoke_host_function` operation. Reflects the contract the user's wallet directly called — *not* contracts called
internally via cross-contract invocation. Cluster key for the table.

NULL when the transaction has no `invoke_host_function` op with a populated root contract — i.e., `invoke_host_function` with sub-type `upload_wasm`, or transactions whose only Soroban ops are
`extend_footprint_ttl` / `restore_footprint`. These cases are kept (LEFT JOIN) so per-metric `COUNT(*)` and `SUM(metric_value)` totals match the raw `history_contract_events` source row-for-row.

{% enddocs %}

{% docs soroban_core_metrics_metric_key %}

Symbol from `topics_decoded[1].symbol` on the host-emitted `core_metrics` diagnostic event. One of 19 values the Soroban host emits per transaction:

* `cpu_insn` — CPU instructions consumed.
* `mem_byte` — Memory bytes allocated during invocation.
* `invoke_time_nsecs` — Invocation time in nanoseconds.
* `read_entry` / `write_entry` — Count of ledger entries read or written.
* `ledger_read_byte` / `ledger_write_byte` — Total bytes read/written to ledger.
* `read_data_byte` / `write_data_byte` — Bytes read/written specifically to `ContractData` entries.
* `read_code_byte` / `write_code_byte` — Bytes read/written to `ContractCode` entries.
* `read_key_byte` / `write_key_byte` — Bytes read/written for ledger entry keys.
* `max_rw_data_byte` / `max_rw_code_byte` / `max_rw_key_byte` — Resource limit caps per byte counter at execution.
* `emit_event` — Count of contract-emitted events.
* `emit_event_byte` — Total bytes of contract-emitted events.
* `max_emit_event_byte` — Resource limit cap for event byte size.

{% enddocs %}

{% docs soroban_core_metrics_metric_value %}

The u64 value of the corresponding `metric_key`, extracted from `data_decoded.u64` and cast to INT64. Always non-null and non-negative. Semantic interpretation depends on `metric_key`: a count for entry/event
metrics, a byte total for byte metrics, a nanosecond duration for `invoke_time_nsecs`, or the protocol-level resource limit for `max_*` metrics.

{% enddocs %}
