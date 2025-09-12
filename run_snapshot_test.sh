#!/bin/sh

set -e
set -x

SELECT_TARGET=$1

if [ -z "$SELECT_TARGET" ]; then
  echo "Error: No argument provided. Please specify the dbt select target."
  exit 1
fi

dbt build --select stg_dummy

dbt run --select "$SELECT_TARGET" --vars '{"setup_db": true}'

dbt build --select "$SELECT_TARGET"

dbt run --select "$SELECT_TARGET" --vars '{"teardown_db": true}'
