# Stellar-dbt
DBT instance to aid in data transformation for analytics purposes

## Table of Contents
- [Getting Started](#getting-started)
- [dbt Setup](#dbt-setup)
    - [Oauth connection](#oauth)
    - [Service Account connection](#service-account-key-file)
    - [Oauth2 Token connection](#oauth-token-based)
- [Working with dbt](#working-with-dbt)
    - [Running Models](#running-models)
    - [Running Tests](#running-tests)
- [Working with Samples](#working-with-samples)
- [Project Structure](#project-structure)
    - [Targets](#targets)
    - [Development Folders](#development-folders)

## Getting Started

In order to develop on this repository, we must first get dbt and follow the installation procedure. First of all, clone the git repository locally. Afterwards, you can follow best practices by setting up a virtual environment for dbt installation or installing it directly (In that case, you can skip to the [dbt setup](#setting-up-dbt)).

After cloning, create a virtual environment for the installation. The recommended python version for dbt is 3.8 and any of its patches.

1. Follow the guide and install the [virtualenv package](https://virtualenv.pypa.io/en/latest/installation.html) through any of the available methods.

2. In order to create a virtual environment, run the command: ``` virtualenv {{env_name}} -p {{python-version}} ```, in case you wish for an specific python environment version, or simply run ``` virtualenv {{env_name}} ``` to install the system's python version on the current repository. More information can be obtained [here](https://virtualenv.pypa.io/en/latest/user_guide.html).

3. Source the virtual environment through: ``` source ~/path/to/venv/bin/activate ```

## dbt Setup

1. Run ``` pip install -r requirements.txt ``` to install all the necessary packages.

2. Run ``` dbt deps ``` to install the utils packages from dbt.

3. By invoking dbt from the CLI, it should parse `dbt_project.yml` and, in case it doesn't already exist, create a `~/.dbt/profiles.yml`. This file exists outside of the project to avoid sensitive credentials in the version control code and it's not recommended to change it's location. **There exists a profile.yml file inside the project folder, but it is not used when developing locally, only for the CI/CD pipeline, and it must not contain any exposed access keys**.

4. In order to connect to the bigquery project, there are a couple methods of authentication supported by BQ. We recommend using Oauth to connect through gcloud CLI tools. Any extra information can be found on the official dbt-bigquery adapter [documentation](https://docs.getdbt.com/reference/warehouse-setups/bigquery-setup#).

### Oauth
5. Oauth - Follow the GCP CLI installation guide [here](https://cloud.google.com/sdk/docs/install). After the installation, run `gcloud init` and provide the requested account information in order to properly setup your Oauth GCP account. The account will be used to run the queries and access the database, so make sure it has the necessary permissions in BigQuery.

6. Open the `profiles.yml` file and add the following configurations:
``` YML
stellar_dbt:
  outputs:
    samples:
      dataset: dbt_sample
      maximum_bytes_billed: 5500000000
      job_execution_timeout_seconds: 300
      job_retries: 1
      location: us-central1
      method: oauth
      priority: interactive
      project: 'test-hubble-319619'
      threads: 1
      type: bigquery
    development:
      dataset: dbt_{{surname}}
      maximum_bytes_billed: 5500000000
      job_execution_timeout_seconds: 300
      job_retries: 1
      location: us-central1
      method: oauth
      priority: interactive
      project: 'test-hubble-319619'
      threads: 1
      type: bigquery
  target: development
```
### Service Account Key File

5. Service Account Key File - Follow the GCP Service Account Key File guide [here](https://cloud.google.com/iam/docs/creating-managing-service-account-keys) in order to generate your file.

6. Open the `profiles.yml` file and add the following configurations:
``` YML
stellar_dbt:
  outputs:
    samples:
      dataset: dbt_sample
      maximum_bytes_billed: 5500000000
      job_execution_timeout_seconds: 300
      job_retries: 1
      location: us-central1
      method: service-account
      keyfile: {{/path/to/bigquery/keyfile.json}}
      priority: interactive
      project: 'test-hubble-319619'
      threads: 1
      type: bigquery
    development:
      dataset: dbt_{{surname}}
      maximum_bytes_billed: 5500000000
      job_execution_timeout_seconds: 300
      job_retries: 1
      location: us-central1
      method: service-account
      keyfile: {{/path/to/bigquery/keyfile.json}}
      priority: interactive
      project: 'test-hubble-319619'
      threads: 1
      type: bigquery
  target: development
```

### Oauth Token Based

5. Oauth Token Based - Follow the GCP Oauth2 guide [here](https://developers.google.com/identity/protocols/oauth2).

6. Open the `profiles.yml` file and add the following configurations:
``` YML
stellar_dbt:
  outputs:
    samples:
      dataset: dbt_sample
      maximum_bytes_billed: 5500000000
      job_execution_timeout_seconds: 300
      job_retries: 1
      location: us-central1
      method: oauth-secrets
      refresh_token: {{token}}
      client_id: {{client id}}
      client_secret: {{client secret}}
      token_uri: {{redirect URI}}
      priority: interactive
      project: 'test-hubble-319619'
      threads: 1
      type: bigquery
    development:
      dataset: dbt_{{surname}}
      maximum_bytes_billed: 5500000000
      job_execution_timeout_seconds: 300
      job_retries: 1
      location: us-central1
      method: oauth-secrets
      refresh_token: {{token}}
      client_id: {{client id}}
      client_secret: {{client secret}}
      token_uri: {{redirect URI}}
      priority: interactive
      project: 'test-hubble-319619'
      threads: 1
      type: bigquery
  target: development
```

Following best practices, each developer has his own dataset for dbt transformations, but shares the same sources. For more information on `profiles.yml` setup, please refer to the dbt [documentation](https://docs.getdbt.com/reference/project-configs/profile).

**Please keep your profile target as development. If you wish to recreate the sample tables, please refer to the [samples](#working-with-samples) section.**

## Working with dbt

### Running Models

Executing a dbt model is the same as executing a SQL script. There are many ways to run dbt models: 

1. Run the entire project through `dbt run`

2. Run tagged models, paths or configs through `dbt run --select tag:tag_1 tag_2 tag_3`.

3. Run specific models through `dbt run --select model_1 model_2 model_3`. **Note that this runs only the specified models, unless you follow said model(s) with execution method #4**

4. Run downstream or upstream models by adding a '+' at the beginning(downstream), end(upstream) or both on the model name `dbt run --select +model_1+`

On top of that, dbt supports --excluding, --defer, --target and many other selection types. To see more, please refer to the [documentation](https://docs.getdbt.com/reference/node-selection/syntax).

### Running Tests

Executing tests works the same way as executing runs, with the command `dbt test` accepting many of the same parameters. This will run both schema tests and unique tests, unless commanded otherwise. For more information on the syntax, consult the [documentation](https://docs.getdbt.com/reference/node-selection/syntax).

In dbt, tests come in two ways. Schema tests, which are pre-built macros and can be called in YML schema files, and unique tests, which are user-made and have their own .SQL files, stored in the `tests` folder. Both tests will be executed during a `dbt test`, unless further node selection is provided. A dbt test will fail when the underlying SQL selection returns a result row, being approved when no rows are returned. For further information on tests, please refer to the [documentation](https://docs.getdbt.com/reference/test-configs).

## Working with samples

In order to reduce costs, sample tables were created from the `test_crypto_stellar_2` dataset, so fewer bytes would be processed while developing. These sources are already created and properly sourced. Following best practices, all development should be done on top of sample tables, with pull requests being tested on the production pipeline automatically during the CI/CD before being merged into the master branch. The Queries used for the creation of the samples can be found inside the `samples` folder.

If there is a need, the samples can be refreshed by selecting a sample period through the `where batch_run_date between {batch_run_start} and {batch_run_finish}` clause in each respective table script, and running dbt with the command `dbt run --target samples`.**It is important to select the same period for every sample table, in order to enable the necessary joins.**

## Project Structure

The Stellar-dbt project follows a staging/marts approach to modelling. The staging step focuses on transforming and preparing the tables for joining on the marts step. In order to diminish cost, all staging .sql files are materialized as ephemeral in the `dbt_project.yml`, allowing code modularity and decoupling while not raising storage costs. 

The marts, on the other hand, are materialized as tables, in order to reduce querying time on the BI and other exposures. It is in this step that tables are joined together to obtain analytical results or rejoin needed information to facilitate date exploration.

### Targets

The project is configured with three targets, being:

| Name | Description |
|------|-------------|
|Samples| Target used to create the sample tables used as source for development|
|Development| Target used during development of new models and analyses, utilizes the sample tables as sources|
|Production| Target exclusive to the production pipeline, it's used only on the CI/CD and deployment of the dbt models|

### Development Folders

| Name | Description |
|------|-------------|
|Sources| Contains the config files for the product source tables, referencing their documentation and, when necessary, testing the raw data with schema tests |
|Samples| Contains the scripts to recreate the sample tables used as sources during development |
|Staging| Scripts that prepare and transform the raw tables for joining and analyses |
|Marts| Scripts that create the Enriched tables as well as analytical tables for partner and BI consumption |
|Docs| Contains the documentation files for the project, used to generate the hosted documentation |
|Macros| Contains any custom Jinja macros created for the project |
|Tests| Contains any custom tests created for the project |
