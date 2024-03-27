#!/bin/sh

pip install -r ./requirements.txt

pre-commit install -c .pre-commit-config.yaml

dbt deps

chmod +x ./pre-commit/cleanup.sh

chmod +x ./pre-commit/for_pre_commit.sh

