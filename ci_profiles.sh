#!/bin/sh

set -e

echo "writing file profiles.yml"
mkdir ~/.dbt

echo "stellar_dbt_public:" >> ~/.dbt/profiles.yml
echo "  target: prod" >> ~/.dbt/profiles.yml
echo "  outputs:" >> ~/.dbt/profiles.yml
echo "    prod:" >> ~/.dbt/profiles.yml
echo "      dataset: crypto_stellar" >> ~/.dbt/profiles.yml
echo "      maximum_bytes_billed: 1000000000000" >> ~/.dbt/profiles.yml
echo "      job_execution_timeout_seconds: 300" >> ~/.dbt/profiles.yml
echo "      job_retries: 1" >> ~/.dbt/profiles.yml
echo "      location: us" >> ~/.dbt/profiles.yml
echo "      priority: interactive" >> ~/.dbt/profiles.yml
echo "      project: crypto-stellar" >> ~/.dbt/profiles.yml
echo "      threads: 1" >> ~/.dbt/profiles.yml
echo "      type: bigquery" >> ~/.dbt/profiles.yml
echo "      method: oauth" >> ~/.dbt/profiles.yml

dbt deps

#echo "starting dbt docs generate"
#dbt docs generate --profiles-dir ~/.dbt
