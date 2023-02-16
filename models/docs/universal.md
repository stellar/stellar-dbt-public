[comment]: < Universal >

{% docs batch_id %}
String representation of the run id for a given DAG in Airflow. Takes the form of "scheduled__<batch_end_date>-<dag_alias>". Batch ids are unique to the batch and help with monitoring and rerun capabilities
{% enddocs %}

{% docs batch_run_date %}
The start date for the batch interval. When taken with the date in the batch_id, the date represents the interval of ledgers processed. The batch run date can be seen as a proxy of closed_at for a ledger. 
{% enddocs %}

{% docs batch_insert_ts %}
The timestamp in UTC when a batch of records was inserted into the database. This field can help identify if a batch executed in real time or as part of a backfill
{% enddocs %}