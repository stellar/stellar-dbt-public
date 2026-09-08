# Developing

These instructions cover setting up stellar-dbt-public locally, running models
and tests, and the conventions for adding a model.

For what this project is and where its output lives, read the
[README](README.md). If you plan to open a pull request, also read the
[contributing guidelines](CONTRIBUTING.md).

## Table of Contents

- [dbt overview](#dbt-overview)
- [Requirements](#requirements)
- [Get the code](#get-the-code)
- [Configure dbt](#configure-dbt)
- [Project structure](#project-structure)
- [Running models](#running-models)
- [Running tests](#running-tests)
- [Linting](#linting)
- [Generating the docs site](#generating-the-docs-site)
- [Continuous integration](#continuous-integration)
- [Tips and notes](#tips-and-notes)

## dbt overview

dbt transforms data without that data ever leaving the warehouse. When you run
`dbt run` or `dbt build`, dbt compiles your models to SQL and executes them
against BigQuery.

- `dbt run` executes the compiled SQL models, without running tests, snapshots,
  or seeds. See the [`dbt run` reference](https://docs.getdbt.com/reference/commands/run).
- `dbt build` does everything `dbt run` does, plus tests, snapshots, and seeds.
  See the [`dbt build` reference](https://docs.getdbt.com/reference/commands/build).

A model is a single `.sql` file containing a final select statement; the
table or view it produces takes the file's name. Each model's
[materialization](https://docs.getdbt.com/docs/build/materializations) decides
how it is persisted. This project uses:

1. [View](https://docs.getdbt.com/docs/build/materializations#view): rebuilt as a view on each run
2. [Table](https://docs.getdbt.com/docs/build/materializations#table): rebuilt as a table on each run
3. [Incremental](https://docs.getdbt.com/docs/build/materializations#incremental): inserts or updates records since the last run
4. [Ephemeral](https://docs.getdbt.com/docs/build/materializations#ephemeral): interpolated into dependent models as a CTE
5. [Materialized View](https://docs.getdbt.com/docs/build/materializations#materialized-view)
6. [Incremental Snapshot](macros/materializations/incremental_snapshot.sql): a
   custom materialization built by SDF to support snapshots with backfilling

> _*Note:*_ If you are new to dbt, start with the
> [dbt documentation](https://docs.getdbt.com/docs/introduction).

## Requirements

- [Git](https://git-scm.com/downloads)
- Python and pip. CI runs Python 3.13; verify your install with
  `python --version` and `pip --version`.
- The [gcloud CLI](https://cloud.google.com/sdk/docs/install)
- A GCP project you can create BigQuery datasets in, and a BigQuery quota
  sufficient for the models you intend to build

Pinned Python dependencies, including `dbt-bigquery` and `sqlfluff`, live in
[requirements.txt](requirements.txt).

## Get the code

```sh
git clone https://github.com/stellar/stellar-dbt-public.git
cd stellar-dbt-public
```

## Configure dbt

1. Create a `.env` file from the example:

   ```sh
   cp example.env .env
   ```

2. Edit the `DBT_*` variables. `profiles.yml` reads all of them from the
   environment, so dbt fails before running any SQL if one is missing.

   | Variable               | What it sets                                        |
   | ---------------------- | --------------------------------------------------- |
   | `DBT_TARGET`           | Target to use: `development`, `test`, or `prod`     |
   | `DBT_PROJECT`          | GCP project ID that dbt connects to                 |
   | `DBT_DATASET`          | BigQuery dataset that dbt writes to                 |
   | `DBT_MAX_BYTES_BILLED` | Ceiling on bytes billed per query                   |
   | `DBT_JOB_TIMEOUT`      | Seconds dbt waits for a query to complete           |
   | `DBT_THREADS`          | Models dbt may build concurrently                   |
   | `DBT_JOB_RETRIES`      | Retries for a failing query                         |

   > _*Important:*_ `example.env` ships with `DBT_TARGET="prod"` and
   > `DBT_PROJECT="crypto-stellar"`, which are the values production uses. For
   > local work set `DBT_TARGET="development"` and point `DBT_PROJECT` and
   > `DBT_DATASET` at **your own** GCP project and a personal dataset. Never run
   > the `prod` target locally.

   `crypto-stellar` is publicly readable, so you can build against it as a
   source while writing output to your own project.

3. Run `setup.sh` to create a virtual environment, install the pinned
   dependencies, install the pre-commit hooks, and run `dbt deps`:

   ```sh
   source setup.sh
   ```

   > _*Note:*_ In each new shell you need to reactivate the environment and
   > reload the variables:
   >
   > ```sh
   > source env/bin/activate
   > source .env
   > ```

4. Authenticate to GCP. Local development uses OAuth:

   ```sh
   gcloud auth login
   gcloud config set project <your gcp project>
   gcloud auth application-default login
   ```

   > _*Note:*_ A GCP service account key also works. See the
   > [dbt BigQuery setup docs](https://docs.getdbt.com/docs/core/connect-data-platform/bigquery-setup#service-account-file).

5. Verify the setup:

   ```sh
   pip list      # confirms the dependencies installed
   dbt debug     # confirms the connection and configuration
   ```

> _*Note:*_ If `dbt debug` fails, check
> [profiles.yml](https://docs.getdbt.com/docs/core/connect-data-platform/profiles.yml)
> and [dbt_project.yml](https://docs.getdbt.com/reference/dbt_project.yml).

## Project structure

The project follows a `staging` → `intermediate` → `marts` approach, with
`snapshots` for history tracking.

| Layer        | Location               | Default materialization       | Purpose                                          |
| ------------ | ---------------------- | ----------------------------- | ------------------------------------------------ |
| Sources      | `models/sources/`      | —                             | Declarations of the raw tables the project reads |
| Staging      | `models/staging/`      | View                          | Source preprocessing, one model per source table |
| Intermediate | `models/intermediate/` | Table                         | Joins, aggregations, and business logic          |
| Marts        | `models/marts/`        | Table                         | Final analytics-ready dimensional models         |
| Snapshots    | `snapshots/`           | Custom `incremental_snapshot` | SCD Type-2 history with `valid_from` / `valid_to` |

Those are the per-directory defaults set in [dbt_project.yml](dbt_project.yml).
Individual models override them in their own `config()` block; most marts are
`incremental` with the `microbatch` strategy rather than full-table rebuilds.

Supporting directories: `macros/` (reusable SQL, including the custom snapshot
materialization), `tests/` (singular tests, plus generic tests in
`tests/generic/`), `seeds/` (small CSVs loaded as tables), `models/docs/` (doc
blocks), and `analyses/`.

### Staging

Receives raw data from the source and prepares it for further transformation.

Do: column selection, renaming columns, casting, flattening structured objects,
initial filters, and basic cleanup such as replacing empty strings with NULL.

Don't: joins or aggregations.

> _*Note:*_ More on the [staging layer](https://docs.getdbt.com/best-practices/how-we-structure/2-staging).

### Intermediate

Prepares data for the marts. Not every staging model becomes an intermediate
model.

Do: joins between staging or intermediate models, aggregations or re-graining to
reach the desired granularity, and complex logic such as business rules or
metrics.

Don't: ingest raw data, do dimensional modeling, or repeat the staging actions.

> _*Note:*_ More on the [intermediate layer](https://docs.getdbt.com/best-practices/how-we-structure/3-intermediate).

### Marts

Where users access the final dimensional models. Every model is accompanied by a
`.yml` file of the same name holding descriptions and tests for the model and
its columns.

Do: organize data into dimension, fact, or aggregate tables; final joins on
staging and intermediate models; mart-specific tweaks; end user documentation;
final testing.

Don't: clean data, or repeat the staging and intermediate actions.

> _*Note:*_ More on the [marts layer](https://docs.getdbt.com/best-practices/how-we-structure/4-marts).

### Snapshots

Captures and tracks changes in source data over time, producing SCD Type-2
tables where each record stores its validity period (`valid_from`, `valid_to`)
and current state. Snapshots answer point-in-time questions, such as what an
account's balance was on a given day.

Do: capture historical change in source or staging tables, maintain
`valid_from` and `valid_to`, use it for entities that need history (accounts,
balances, contracts), apply deterministic backfills or repairs through Airflow
orchestration, and build on the custom snapshot macros rather than native dbt
snapshots so backfills stay possible.

Don't: perform business aggregations or heavy joins — leave those to
intermediate and marts — store unrelated business logic, or snapshot data that
does not change, such as static reference tables.

> _*Note:*_ The custom materialization, its macros, orchestration, and repair
> procedure are documented in [docs/snapshot.md](docs/snapshot.md).

## Running models

Running a dbt model is like running a SQL script. There are several ways to
select what runs:

```sh
# The entire project
dbt <run or build>

# By tag, path, or config
dbt <run or build> --select tag:tag_1 tag_2 tag_3

# Specific models, and none of their dependencies
dbt <run or build> --select model_1 model_2 model_3

# A model plus its upstream (+ prefix) and downstream (+ suffix) models
dbt <run or build> --select +model_1+
```

> _*Note:*_ dbt also supports `--exclude`, `--defer`, `--target`, and many other
> selection methods. See the
> [node selection syntax](https://docs.getdbt.com/reference/node-selection/syntax).

### Batch window variables

Incremental models and several tests are scoped by variables that Airflow sets
per task and that default to placeholder dates in
[dbt_project.yml](dbt_project.yml): `batch_start_date`, `batch_end_date`,
`execution_date`, `snapshot_start_date`, `snapshot_end_date`, and
`is_singular_airflow_task`.

The defaults are deliberately wide or inert, which means a local run can select
zero rows and still report success. Pass an explicit window to reproduce what
production does:

```sh
dbt run --select my_incremental_model \
  --vars '{batch_start_date: "2024-06-01", batch_end_date: "2024-06-02"}'
```

## Running tests

Run tests with `dbt test`, or with `dbt build` to build and test together, using
the same [node selection syntax](https://docs.getdbt.com/reference/node-selection/syntax)
as `dbt run`. Both schema and data tests run unless explicitly excluded.

There are three kinds of test:

1. **Singular data tests** — a SQL query in `tests/` that returns failing rows.
2. **Generic data tests** — parameterized queries applied from a model's `.yml`
   file. This project defines its own in `tests/generic/`, including
   `incremental_not_null`, `incremental_unique`,
   `incremental_unique_combination_of_columns`, `incremental_accepted_values`,
   `recency`, and `test_expression_is_true`. These are date-scoped variants of
   the standard tests, so they check only the batch window rather than the whole
   table.
3. **Unit tests** — validate model logic against static inputs without
   materializing the model. This project does not define any yet; they are worth
   reaching for when a model's logic is intricate enough that a data test would
   only catch the problem after a full build.

> _*Note:*_ More on [data tests](https://docs.getdbt.com/docs/build/data-tests)
> and [unit tests](https://docs.getdbt.com/docs/build/unit-tests).

Accepted, already-triaged test failures are recorded in
`seeds/public_test_exceptions.csv` rather than by disabling the test. Read
[docs/test_exceptions.md](docs/test_exceptions.md) before adding a row.

## Linting

`setup.sh` installs the pre-commit hooks. Run them over everything before
opening a pull request:

```sh
pre-commit run --all-files
```

The hooks are [sqlfluff](https://docs.sqlfluff.com/) lint and fix, configured by
[.sqlfluff](.sqlfluff) for the BigQuery dialect and the dbt templater, plus
`prettier` for JSON and YAML and a handful of hygiene checks.

You can also run sqlfluff directly:

```sh
sqlfluff lint models/path/to/model.sql
sqlfluff fix models/path/to/model.sql
```

> _*Note:*_ The sqlfluff hooks shell out to `pre-commit/for_pre_commit.sh`,
> which copies `.env` to `.env.tmp` and loads it. A missing or malformed `.env`
> therefore fails the hook rather than the SQL.

## Generating the docs site

```sh
dbt docs generate
dbt docs serve
```

Merges to `master` regenerate the published docs site and upload it to GCS.

Column descriptions come from two places: the `.yml` co-located with each model,
and shared doc blocks in `models/docs/` referenced as `{{ doc('column_name') }}`.
Columns that mean the same thing everywhere belong in
`models/docs/universal.md`. When you add or change a model, update both the
co-located `.yml` and any relevant doc block.

## Continuous integration

A pull request runs three checks:

| Check                     | What it does                                                                                    |
| ------------------------- | ----------------------------------------------------------------------------------------------- |
| CI Linting                | Runs pre-commit on the changed files, then `diff-quality --violations=sqlfluff --fail-under=95` |
| dbt project evaluator CI  | Builds the `dbt_project_evaluator` package against `test-hubble-319619`                         |
| Socket security scan      | Scans dependency changes                                                                        |

The CI Linting job **skips** the sqlfluff pre-commit hooks and relies on
`diff-quality` instead, which scores only the lines your branch changed and
fails below 95. So a file with pre-existing violations can pass while your new
lines fail. Run sqlfluff locally on the files you touched.

## Tips and notes

- `dbt deps` installs packages into `dbt_packages/`, which goes stale as soon as
  a pin in `packages.yml` moves. Re-run `dbt deps` after pulling, before
  trusting compiled output or lineage.
- `dbt --quiet` suppresses the model-by-model output, which can make a run that
  did nothing look like a run that succeeded. Check the row counts.
- If a selector matches nothing, dbt exits successfully. Models that come from a
  package need `fqn:` or `package:` selectors rather than a bare name.
- The `development` and `test` targets inherit every setting from `prod` in
  [profiles.yml](profiles.yml) except the project and dataset you supply, so a
  misconfigured `.env` points a local run straight at production.
