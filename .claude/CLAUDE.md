# CLAUDE.md

## Project Overview

This is a dbt (data build tool) project that models Stellar blockchain data on BigQuery. It transforms raw Stellar network history, state tables, and third party data tables into analytics-ready datasets.

## Setup

```bash
source setup.sh        # Creates virtualenv, installs dbt-bigquery, sqlfluff, pre-commit hooks
source .env            # Load environment variables
dbt debug              # Verify connection and configuration
dbt deps               # Install dbt packages
```

Required environment variables (see `profiles.yml`):
- `DBT_TARGET` — target environment (`prod`, `test`, or `development`)
- `DBT_DATASET` — BigQuery dataset name
- `DBT_PROJECT` — GCP project ID
- `DBT_MAX_BYTES_BILLED`, `DBT_JOB_TIMEOUT`, `DBT_THREADS`, `DBT_JOB_RETRIES` — optional tuning

## Common Commands

```bash
dbt run                              # Run all models
dbt build                            # Run models + tests + seeds + snapshots
dbt test                             # Run all tests
dbt run --select model_name          # Run a single model
dbt run --select +model_name+        # Run with upstream and downstream dependencies
dbt run --select tag:tag_name        # Run by tag
dbt docs generate                    # Generate documentation site

# Lint SQL (also runs automatically via pre-commit)
sqlfluff lint models/path/to/model.sql
sqlfluff fix models/path/to/model.sql
```

## Architecture

### Model Layers

| Layer | Location | Materialization | Purpose |
|-------|----------|-----------------|---------|
| Staging (`stg_*`) | `models/staging/` | View | Source preprocessing: column selection, renaming, casting, flattening. No joins. |
| Intermediate (`int_*`) | `models/intermediate/` | View | Business logic: joins, aggregations, enrichment |
| Marts | `models/marts/` | Incremental Table | Final analytics-ready tables, partitioned and clustered |
| Snapshots | `snapshots/` | Custom `incremental_snapshot` | SCD Type-2 history with backfill support |

### Data Flow

```
Raw BigQuery Sources (crypto-stellar project)
  → Staging views (stg_*)
    → Intermediate views (int_*)
      → Mart incremental tables (partitioned by date)
      → Snapshot tables (valid_from / valid_to tracking)
```

### Key Domains

- **`account_balances/`** — Daily account balance aggregations across trustlines, liquidity pools, and contracts
- **`enriched_history/`** — Augmented blockchain history (transactions, operations, trades, effects)
- **`ledger_current_state/`** — Current state dimension tables (accounts_current, trust_lines_current, offers_current, etc.)
- **`tokens/`** — Token metadata enrichment pipeline
- **`reflector_prices/`** — CEX/DEX/FEX price data from Reflector oracle

### Custom Snapshot Materialization

Snapshots use a **custom `incremental_snapshot` materialization** (not native dbt snapshots). Key macros:
- `backfill_snapshot()` — Rebuilds a date range deterministically
- `calculate_snapshot_diff_for_day()` — Computes SCD changes for a single day
- `calculate_snapshot_diff_for_day_range()` — Batch range processing

Variables for snapshot control:
- `snapshot_start_date`, `snapshot_end_date` — Explicit date range for backfills
- `batch_start_date`, `batch_end_date` — Batch processing range
- `execution_date` — Current execution timestamp (used by Airflow)
- `is_recency_airflow_task` — Flag for Airflow task type

See `docs/snapshot.md` for the full control flow diagram.

## Testing

### Generic Tests (custom implementations in `macros/tests/`)
- `incremental_not_null` — Date-scoped null checks for incremental models
- `incremental_unique` / `incremental_unique_combination_of_columns` — Incremental uniqueness
- `incremental_accepted_values` — Incremental value validation
- `test_expression_is_true` — Custom expression validation

### Singular Tests (`tests/`)
- Anomaly detection for trades (count, volume)
- Data quality checks (ledger sequence increments, transaction counts)
- Infrastructure monitoring (bucketlist size, Soroban pricing)

## Documentation

- **Universal column definitions**: `models/docs/universal.md` — referenced via `{{ doc('column_name') }}` in YAML schema files
- **Domain docs**: `models/docs/sources/`, `models/docs/snapshots/`, `models/docs/marts/`, `models/docs/intermediate/`
- Each SQL model has a co-located `.yml` schema file with column descriptions and tests

When adding or modifying models, update both the co-located YAML and any relevant doc blocks in `models/docs/`.

## Pre-commit Hooks

Pre-commit runs automatically on commit:
1. **SQLFluff** — lints and auto-fixes SQL style
2. **dbt-checkpoint** — enforces:
   - All model columns in `marts/` must have descriptions in `.yml`
   - All mart models must have a description
   - Model tags must be from the approved allowlist (see `.pre-commit-config.yaml`)
   - All source columns/tables must have descriptions
3. **Prettier** — formats `.json`/`.yaml`/`.yml` files

## Rules

- Never run any dbt commands that would write or modify datasets in the GCP projects `crypto-stellar` or `hubble-261722`
- Run sqlfluff and tests before considering a task complete
- Prefer small and focused changes over large rewrites
- Keep PRs scoped to only the request
- Never commit secrets, API keys, or credentials
