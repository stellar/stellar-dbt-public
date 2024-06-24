[comment]: < Config Settings -

{% docs config_settings %}
The config settings table contains the configuration information for Soroban contract resources.
These settings are set at the network level and requires a validator vote to update.
[XDR defining the config settings](https://github.com/stellar/stellar-xdr/blob/curr/Stellar-contract-config-setting.x)
[Fees and metering docs](https://soroban.stellar.org/docs/soroban-internals/fees-and-metering#cost-parameters)
{% enddocs %}

{% docs config_setting_id %}
Config setting id types

| id  | Type                                                          |
| --- | ------------------------------------------------------------- |
| 0   | ConfigSettingIdConfigSettingContractMaxSizeBytes              |
| 1   | ConfigSettingIdConfigSettingContractComputeV0                 |
| 2   | ConfigSettingIdConfigSettingContractLedgerCostV0              |
| 3   | ConfigSettingIdConfigSettingContractHistoricalDataV0          |
| 4   | ConfigSettingIdConfigSettingContractEventsV0                  |
| 5   | ConfigSettingIdConfigSettingContractBandwidthV0               |
| 6   | ConfigSettingIdConfigSettingContractCostParamsCpuInstructions |
| 7   | ConfigSettingIdConfigSettingContractCostParamsMemoryBytes     |
| 8   | ConfigSettingIdConfigSettingContractDataKeySizeBytes          |
| 9   | ConfigSettingIdConfigSettingContractDataEntrySizeBytes        |
| 10  | ConfigSettingIdConfigSettingStateTtl                          |
| 11  | ConfigSettingIdConfigSettingContractExecutionLanes            |
| 12  | ConfigSettingIdConfigSettingBucketlistSizeWindow              |
| 13  | ConfigSettingIdConfigSettingEvictionIterator                  |

{% enddocs %}

{% docs contract_max_size_bytes %}
Max size of contract
{% enddocs %}

{% docs ledger_max_instructions %}
Max instructions per ledger
{% enddocs %}

{% docs tx_max_instructions %}
Max instructions per transaction
{% enddocs %}

{% docs fee_rate_per_instructions_increment %}
Fee for instructions increment
{% enddocs %}

{% docs tx_memory_limit %}
Transaction memory limit
{% enddocs %}

{% docs ledger_max_read_ledger_entries %}
Max read ledger entries per ledger
{% enddocs %}

{% docs ledger_max_read_bytes %}
Max read bytes per ledger
{% enddocs %}

{% docs ledger_max_write_ledger_entries %}
Max write ledger entries per ledger
{% enddocs %}

{% docs ledger_max_write_bytes %}
Max write bytes per ledger
{% enddocs %}

{% docs tx_max_read_ledger_entries %}
Max read ledger entries per transaction
{% enddocs %}

{% docs tx_max_read_bytes %}
Max read bytes per transaction
{% enddocs %}

{% docs tx_max_write_ledger_entries %}
Max write ledger entries per transaction
{% enddocs %}

{% docs tx_max_write_bytes %}
Max write bytes per transaction
{% enddocs %}

{% docs fee_read_ledger_entry %}
Fee for read ledger entry
{% enddocs %}

{% docs fee_write_ledger_entry %}
Fee for write ledger entry
{% enddocs %}

{% docs fee_read_1kb %}
Fee per 1kb read
{% enddocs %}

{% docs bucket_list_target_size_bytes %}
bucket list target size
{% enddocs %}

{% docs write_fee_1kb_bucket_list_low %}
Write fee for bucket list per 1kb
{% enddocs %}

{% docs write_fee_1kb_bucket_list_high %}
Write fee for bucket list per 1kb
{% enddocs %}

{% docs bucket_list_write_fee_growth_factor %}
Write growth fee for bucket list
{% enddocs %}

{% docs fee_historical_1kb %}
Fee for historical storage per 1kb
{% enddocs %}

{% docs tx_max_contract_events_size_bytes %}
Max transaction contract event size
{% enddocs %}

{% docs fee_contract_events_1kb %}
Fee for contract event size per 1kb
{% enddocs %}

{% docs ledger_max_txs_size_bytes %}
Max ledger transaction size
{% enddocs %}

{% docs tx_max_size_bytes %}
Max transaction size
{% enddocs %}

{% docs fee_tx_size_1kb %}
Fee for transaction size per 1kb
{% enddocs %}

{% docs contract_cost_params_cpu_insns %}
Constant and linear model parameters for cost parameters for cpu
{% enddocs %}

{% docs contract_cost_params_mem_bytes %}
Constant and linear model parameters for cost parameters for memory
{% enddocs %}

{% docs contract_data_key_size_bytes %}
Max size of contract data keys
{% enddocs %}

{% docs contract_data_entry_size_bytes %}
Max size of contract data entries
{% enddocs %}

{% docs max_entry_ttl %}
Max ttl that can be set for an entry (sequence created at + this)
{% enddocs %}

{% docs min_temp_entry_ttl %}
Min temporary entry ttl (sequence created at + this)
{% enddocs %}

{% docs min_persistent_entry_ttl %}
Min persistent entry ttl (sequence created at + this)
{% enddocs %}

{% docs auto_bump_ledgers %}
Automatic bump ledgers amount
{% enddocs %}

{% docs persistent_rent_rate_denominator %}
Persistent entry rent rate denominator
{% enddocs %}

{% docs temp_rent_rate_denominator %}
Temporary entry rent rate denominator
{% enddocs %}

{% docs max_entries_to_ttl %}
Max entries to ttl
{% enddocs %}

{% docs bucket_list_size_window_sample_size %}
Bucket list size window sample size
{% enddocs %}

{% docs eviction_scan_size %}
Eviction scan size
{% enddocs %}

{% docs starting_eviction_scan_level %}
Starting eviction scan level
{% enddocs %}

{% docs ledger_max_tx_count %}
Max transactions in a ledger
{% enddocs %}

{% docs bucket_list_size_window %}
Bucket list size window
{% enddocs %}

{% docs min_temporary_ttl %}
The minimum number of entries for which a temporary entry can live on the ledger.
{% enddocs %}

{% docs min_persistent_ttl %}
The minimum number of entries for which a persisted entry can live on the ledger.
{% enddocs %}

{% docs max_entries_to_archive %}
Maximum number of entries that emit archival meta in a single ledger
{% enddocs %}
