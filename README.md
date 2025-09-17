# stellar-dbt-public

Public dbt instance to aid in data transformation for analytics purposes.
If you're interested in setting up your own dbt project, you can find detailed instructions in the [dbt documentation](https://docs.getdbt.com/docs/introduction).

## Before creating a branch

Pay attention, it is very important to know if your modification to this repository is a release (breaking changes), a feature (functionalities) or a patch(to fix bugs). With that information, create your branch name like this:

- `major/<branch-name>`
- `minor/<branch-name>`
- `patch/<branch-name>`

If branch is already made, just rename it _before passing the pull request_.

# Table of Contents

- [dbt Overview](#dbt-overview)
  - [Workflow](#workflow)
  - [dbt Project Structure](#dbt-project-structure)
    - [Development Folders](#development-folders)
  - [Tests](#tests)
- [Getting Started](#getting-started)
  - [Download the Repo](#download-the-repo)
  - [Configure dbt](#configure-dbt)
- [Working with dbt](#working-with-dbt)
  - [Running Models](#running-models)
  - [Running Tests](#running-tests)
- [New Releases](#New-code-release)

# dbt Overview

dbt is composed of different moving parts working harmoniously. All of them are important to what dbt does — transforming data. When you execute `dbt run` or `dbt build`, you are running a model that will transform your data without that data ever leaving your warehouse.

`dbt run` will execute the compiled sql models without running tests, snapshots, nor seeds (if there are any). More information about `dbt run` can be found [here](https://docs.getdbt.com/reference/commands/run)

`dbt build` will do everything `dbt run` does plus run tests, snapshots, and seeds (if there are any). More information about `dbt build` can be found [here](https://docs.getdbt.com/reference/commands/build)

## Workflow

The top level of a dbt workflow is the project. A project generally consists of a project configuration `.yml` (in this case the [dbt_project.yml](https://github.com/stellar/stellar-dbt-public/blob/master/dbt_project.yml)) and a directory of the [models](https://github.com/stellar/stellar-dbt-public/tree/master/models). The `dbt_project.yml` tells dbt the project context, and the models let dbt know how to build a specific data set. These models simplify analytics by generating data mart tables.

A model is a single `.sql` file containing a final select statement for the table or view. The table/view name is the same as the file name. A project can have multiple models where a model can be classified as a staging, intermediate, or mart table/view.

In dbt, you can configure the materialization of your models. Materializations are strategies for persisting dbt models in a warehouse. There are five types of materializations built into dbt. They are:

1. [View](https://docs.getdbt.com/docs/build/materializations#view): your model is rebuilt as a view on each run
2. [Table](https://docs.getdbt.com/docs/build/materializations#table): your model is rebuilt as a table on each run
3. [Incremental](https://docs.getdbt.com/docs/build/materializations#incremental): allows dbt to insert or update records into a table since the last time that dbt was run
4. [Ephemeral](https://docs.getdbt.com/docs/build/materializations#ephemeral): these are not directly built into the database. instead, dbt will interpolate the code from this model into dependent models as a common table expression
5. [Materialized View](https://docs.getdbt.com/docs/build/materializations#materialized-view): allows the creation and maintenance of materialized views in the target database
6. [Incremental Snapshot](./macros/materializations/incremental_snapshot.sql): This is a custom materialization built by SDF to support snapshots with backfilling capabilities.

> _*Note:*_ More information about materializations can be found [here](https://docs.getdbt.com/docs/build/materializations#overview)

> _*Note:*_ More information about dbt projects can be found [here](https://docs.getdbt.com/docs/build/projects).

## dbt Project Structure

The stellar-dbt-public project follows a `staging`, `intermediate`, and `marts` approach to modeling.

1. Staging
   The purpose of the staging layer is to receive the raw data from the source and prepare it for further transformations and analysis.

What to do in staging:

- Column selection
- Renaming columns
- Definition of data types (casting columns to String, Numeric...)
- Flattening of structured objects
- Initial filters
- Basic cleanup, like replacing empty strings with NULL, for example

What not to do in staging:

- Joins
- Aggregations

> _*Note:*_ More information about `staging` layer can be found [here](https://docs.getdbt.com/best-practices/how-we-structure/2-staging).

2. Intermediate
   In the intermediate layer, the preparation for directing the data to the marts takes place. Not every model in the staging layer will become an intermediate model. This is where it is possible to combine different models to start assembling business rules.

What to do in intermediate:

- Joins between different staging or intermediate models
- Aggregations or re-graining to fan out or collapse columns to the desired granularity
- Complex logic such as the integration of business logic, rules, or metrics

What not to do in intermediate:

- Ingestion of raw data
- Dimensional modeling (creation of fact, dimension, or aggregate tables)
- The actions listed in staging

> _*Note:*_ More information about `intermediate` layer can be found [here](https://docs.getdbt.com/best-practices/how-we-structure/3-intermediate).

3. Marts
   The marts layer is where users can access final dimensional modeling tables. Each model will be accompanied by a `.yml` file with the same name. The `.yml` file contains the descriptions and tests for the model and its columns.

What to do in marts:

- Organization of data into dimension, fact, or aggregate tables
- Mart-specific tweaks
- Final joins for staging and intermediate models
- End user documentation
- Final testing

What not to do in marts:

- Data cleaning
- The actions listed in staging or intermediate

> _*Note:*_ More information about `marts` layer can be found [here](https://docs.getdbt.com/best-practices/how-we-structure/4-marts).


4. Snapshots
   The snapshots layer is used to capture and track changes in source data over time. It allows us to build Slowly Changing Dimension (SCD) Type-2 tables, where each record stores both its validity period (valid_from, valid_to) and current state. Snapshots enable analysts to answer point-in-time questions (e.g., “What was a user’s balance on March 30, 2024?”).

What to do in snapshots:

- Capture historical changes in source or staging tables
- Maintain valid_from and valid_to fields for tracking record validity
- Use for entities that require historical tracking (users, balances, contracts, etc.)
- Apply deterministic backfills or repairs using Airflow orchestration
- Build on top of custom snapshot macros (instead of DBT native snapshots) for reliability and backfilling capabilites.

What not to do in snapshots:

- Perform business aggregations or heavy joins (leave this to intermediate/marts)
- Store unrelated business logic — snapshots should focus only on state tracking
- Use for data that does not require historical changes (e.g., static reference tables)

> _*Note:*_ More information about `snapshot` in this project (custom materialization, macros, orchestration, and repairs) can be found in [here](./docs/snapshot.md)

### Development Folders

| Name         | Description                                                                                   |
| ------------ | --------------------------------------------------------------------------------------------- |
| Source       | Stores the raw data that will be used as inputs for the dbt transformations.                  |
| Staging      | Stages the pre-processed or cleaned data before performing the transformations.               |
| Intermediate | Contains the transformed and processed data.                                                  |
| Marts        | Houses the final data models or data marts, which are the end results of the dbt project.     |
| Docs         | Stores documentation related to your dbt project.                                             |
| Macros       | Contains reusable SQL code snippets known as macros.                                          |
| Tests        | Contains defining tests to validate the accuracy and correctness of the data transformations. |

## Tests

Tests are assertions made about models and other resources in the dbt project. When you run `dbt test` or `dbt build`, dbt will tell you if each test in your project passes or fails.

There are three different test types:

1. Singular data tests: a SQL query that returns failing rows
2. Generic data tests: is a parameterized query that accepts arguments. The test query is defined in a special test block (like a macro)
3. Unit tests: validates SQL modeling logic on a small set of static inputs before materializing the full model

> _*Note:*_ More information about `data tests` can be found [here](https://docs.getdbt.com/docs/build/data-tests)

> _*Note:*_ More information about `unit tests` can be found [here](https://docs.getdbt.com/docs/build/unit-tests)

<br>

---

# Getting Started

## Download the Repo

Clone the git repository locally

```
git clone https://github.com/stellar/stellar-dbt-public.git
```

## Configure dbt

1. Create a new `.env` file by copying `example.env`

```
cp example.env .env
```

2. Set the various `DBT_*` variables (e.g. `DBT_DATASET`, `DBT_PROJECT`)
3. Execute `setup.sh` to create a virtual environment and install required dbt dependencies

```
source setup.sh
```

4. Set up OAuth by running `gloud init` and following the account information prompts
5. To verify if all libraries have been correctly installed, use the command `pip list`
6. Execute the command `dbt debug` to ensure that all configurations are working correctly

> _*Note:*_ You can find instructions to install the `GCP CLI` [here](https://cloud.google.com/sdk/docs/install)

> _*Note:*_ More information about `dbt core` setup can be found [here](https://docs.getdbt.com/docs/core/about-core-setup)

> _*Note:*_ You may need to modify `profiles.yml` and `dbt_project.yml` if any of the above commands fail
> <br> [profiles.yml docs](https://docs.getdbt.com/docs/core/connect-data-platform/profiles.yml) > <br> [dbt_project.yml docs](https://docs.getdbt.com/reference/dbt_project.yml)

<br>

---

# Working with dbt

## Running Models

Executing a dbt model is the same as executing a SQL script. There are many ways to run dbt models:

1. Run the entire project with

```
dbt <run or build>
```

2. Run tagged models, paths, or configs with

```
dbt <run or build> --select tag:tag_1 tag_2 tag_3
```

3. Run specific models with

```
dbt <run or build> --select model_1 model_2 model_3
```

> _*Note:*_ this runs only the specified models and none of its dependencies

4. Run the model with its downstream and/or upstream models by adding a `+` to the beginning (downstream) and/or the end (upstream) of the model name

```
dbt <run or build> --select +model_1+
```

> _*Note:*_ dbt supports `--excluding`, `--defer`, `--target`, and many other selection types. Please refer to the [node selection syntax documentation](https://docs.getdbt.com/reference/node-selection/syntax).

## Running Tests

Execute tests with the commands `dbt test` or `dbt build` with the desired [node selection syntax](https://docs.getdbt.com/reference/node-selection/syntax). This will run schema, data, and unit tests unless they are explicitly excluded. More information about tests can be found [here](https://docs.getdbt.com/reference/commands/test).

# New Releases

In order to enable other repositories to work with and build on top of this dbt repo, it was configured as a package. Due to this, commiting to the repository requires a few extra steps to ensure git tagging is consistent, so that changes will not break any code downstream. When commiting changes, there are 3 main version changes that can be applied to the repository, as follows:

| Change | Description                                                                |
| ------ | -------------------------------------------------------------------------- |
| Major  | Version when making incompatible changes                                   |
| Minor  | Version change when adding functionalities in a backward compatible manner |
| Patch  | Version change when making backward compatible bug fixes                   |

In order to apply git tagging properly, the last commit message from a repo must contain a hashtag(#) followed by the change type present in that commit. This will allow github to detect the type of change being pushed and increment the version accordingly. For example:

`'Fix trade-agg bug #patch'`

# Futher Development

TODO
