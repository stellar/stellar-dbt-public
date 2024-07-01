#!/bin/sh

#if something goes wrong, stop the script
set -e

# exports all variables in .env file. Any variable defined in the script will be available in the environment.
set -a
# Install virtualenv if not installed
pip install virtualenv

# Create a new virtual environment
virtualenv env

# It gives permission to activate the virtual environment
chmod +x ./env/bin/activate

# Activate the virtual environment
source env/bin/activate  # On Windows, use `env\Scripts\activate`

# # Load the environment variables
source .env

# Install requirements
pip install -r ./requirements.txt

# It installs pre-commit hooks into your Git repository.
pre-commit install -c .pre-commit-config.yaml

# Dbt deps command is used to download and manage the dependencies of a dbt project.
dbt deps

# It gives permission to execute the cleanup script
chmod +x ./pre-commit/cleanup.sh

# It gives permission to execute the for_pre_commit script
chmod +x ./pre-commit/for_pre_commit.sh
