[comment]: < Configuration Settings Snapshot -

{% docs config_settings_snapshot %}

This table captures historical snapshots of various configuration settings from the Stellar network. It unpivots different metric values from the `config_settings` table and tracks their validity over time.

Each metric represents a specific setting related to transaction limits, ledger constraints, fees, and other network parameters. The `valid_from` and `valid_to` timestamps help in identifying when each setting was active.

The table is enriched with metric mapping data from the `config_setting_to_metrics_mapping` seed, providing core metric names, granularity levels, and human-readable display names for each config setting.

{% enddocs %}

{% docs config_setting_name %}

The name of the configuration setting (metric) extracted from the source table. Each row represents a different setting tracked over time.

{% enddocs %}

{% docs setting_value %}

The numeric value associated with the configuration setting. This value represents the active limit, fee, or constraint set by the network.

{% enddocs %}

{% docs is_current_setting %}

Boolean flag indicating if the setting is currently in effect (`true` if `valid_to` is null).

{% enddocs %}
