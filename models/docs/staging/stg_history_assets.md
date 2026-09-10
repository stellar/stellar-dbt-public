[comment]: < Staging History Assets -

{% docs stg_history_assets__dedup_oldest_asset %}
Row number over the rows in `history_assets_staging` that share an `asset_id`, ordered by `batch_run_date` descending. The view keeps only rows where this is 1, so each asset appears once with its most recent batch.
{% enddocs %}
