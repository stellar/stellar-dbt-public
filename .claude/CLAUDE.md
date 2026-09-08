# CLAUDE.md

## Critical rules — read these first

- **NEVER run dbt with the `prod` target locally.** Local runs use the `development` target and your personal dev dataset.
- **NEVER run any dbt command that writes to or modifies datasets in the GCP projects `crypto-stellar` or `hubble-261722`.**
- **This repo is consumed by `stellar-dbt` as a git package pinned by tag.** Merging here does NOT ship the change internally — the internal repo needs a `packages.yml` pin bump plus `dbt deps` (see the `cross-repo-release` skill).
- **Run `pre-commit run --all-files` before considering a task complete** and fix every reported issue.
- For queries with int64 IDs (`op_id`, `transaction_id`, ledger sequences), use the `bq` CLI — MCP query tools silently round large integers.
- Never commit secrets, API keys, or credentials. Prefer small focused changes; keep PRs scoped to the request.

## Skills — load the matching one BEFORE starting

Skills live in the data-platform monorepo checkout under `.claude/skills/` — `../.claude/skills/` when this repo sits inside that checkout. They are readable as plain files from anywhere; they load as skills when the session starts at the monorepo root.

| Task | Skill |
|---|---|
| Fresh local setup; `dbt debug`/env-var errors | `dbt-local-setup` |
| PR check failing (CI Linting, diff-quality, Datafold diff comment) | `dbt-ci-triage` |
| Create/modify/repair an SCD2 snapshot model | `dbt-incremental-snapshots` |
| Model behaves differently locally vs in Airflow; incremental runs 0 rows | `dbt-batch-window-vars` |
| Slow or expensive model; merge vs insert_overwrite | `dbt-model-optimization` |
| Shipping a change that the internal repo must consume (pin bump) | `cross-repo-release` |
| Selector matches nothing; `--quiet` hides output | `dbt-learnings` |

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

Snapshots use a **custom `incremental_snapshot` materialization** (not native dbt snapshots). A run rebuilds from `snapshot_start_date` to `snapshot_end_date`, in chunks. Key macros:
- `calculate_snapshot_diff()` — Computes one chunk's SCD changes
- `snapshot_reset_from_start()` — Returns the target to its state at the start date
- `snapshot_chunk_ranges()` — Splits the window into consecutive chunks
- `snapshot_key_filter()` — Optionally scopes a rebuild to named entities
- `snapshot_begin()` — A model's full-refresh start date, windowed under `target=ci`

Variables for snapshot control:
- `snapshot_start_date` — Where a rebuild starts; `snapshot_end_date` bounds the rebuild (defaults to today) but not the delete, so a past end date truncates rather than repairs
- `snapshot_keys` — Restrict a rebuild to named entities (never on `prod`)
- `batch_start_date`, `batch_end_date` — Batch processing range
- `execution_date` — Current execution timestamp (used by Airflow)
- `is_recency_airflow_task` — Flag for Airflow task type

See `docs/snapshot.md` for the full control flow diagram. For hands-on snapshot work (run_snapshot_test.sh, setup_db/teardown_db, missing-days holes), use the `dbt-incremental-snapshots` skill.

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

Full process: `docs/documentation.md`. Enforced by `scripts/docs_lint.py check` (pre-commit hook `docs-lint`).

- **Descriptions live in doc blocks, never inline in yml.** The `.yml` carries `description: '{{ doc("name") }}'`; the text lives in a `.md` under `models/docs/`, which mirrors `models/`. Definitions that unrelated tables share go in `models/docs/universal.md`.
- **Name a shared block after the bare column** (`asset_code`); a model-specific one is `<model>__<column>`. Two columns share a block only when they mean the same thing at the same grain.
- **Block names resolve by name, not by file**, so moving a block is safe but renaming one breaks the ~200 `doc()` references `stellar-dbt` resolves into this repo.

**`check` only verifies a description *is* a reference, not that the reference is *correct*.** `- name: operation_id` with `doc("transaction_id")` passes and publishes the wrong text; 21 references here were wrong this way. So `grep -rn "{% docs <column> %}" models/docs/` and **read the block's text before referencing it** — never copy a neighbouring line. These cluster on paired columns (`asset_a`/`asset_b`, `read_bytes`/`write_bytes`, `batch_id`/`batch_run_date`).

Prove a docs change rendered what you intended, with no warehouse connection:

```bash
git stash && ./venv/bin/python scripts/docs_lint.py snapshot --out /tmp/before.json
git stash pop && ./venv/bin/python scripts/docs_lint.py snapshot --out /tmp/after.json
./venv/bin/python scripts/docs_lint.py diff /tmp/before.json /tmp/after.json
```

A relocation must print `0 differences`; a text change must print exactly what you meant. Put that output in the PR.

## Pre-commit Hooks

Pre-commit runs automatically on commit. Run it manually before finishing any task:

```bash
pre-commit run --all-files        # Run all hooks on all files
pre-commit run --files path/to/file.sql   # Run on specific files
```

Hooks, in the order they run (see `.pre-commit-config.yaml`):

1. **pre-commit-hooks basics** — trailing whitespace, end-of-file newline, mixed line endings, byte-order marker, large files, case conflicts, merge conflicts, private keys, `requirements.txt` sorting
2. **Prettier** — formats `.json`/`.yaml`/`.yml` files
3. **SQLFluff** — `sqlfluff-lint` then `sqlfluff-fix`, via `pre-commit/for_pre_commit.sh`
4. **docs-lint** — runs `scripts/docs_lint.py check`: no repeated descriptions, no `doc()` pointing at a missing or wrong block, shared definitions in `models/docs/universal.md`. See the Documentation section above
5. **cleanup** — removes `.env.tmp`

This repo has **no dbt-checkpoint hooks**; that is `stellar-dbt`'s config, not this one. `docs-lint` is what enforces description quality here, and it checks for duplication rather than mere presence.

`pre_commit run --files <list>` can report "no files to check" in some environments; `--all-files` is the reliable invocation.
