# Test exceptions

`seeds/public_test_exceptions.csv` is the one place this package records known,
accepted data-quality test failures, so a pipeline stops alerting on a situation we
have already triaged.

Alerting on these tests is task-level: the Airflow task running them fails if *any*
test in it fails, and there is no per-test routing. So the only way to stop alerting
on a known failure is to stop the test returning those rows — which is what this
table does, without disabling the test.

## The two kinds of row

**`temporary`** — an accepted failure we expect to go away. `expires_on` is
required. When it passes, the exception stops applying and the test starts failing
again; that is the review mechanism, which is why there is no separate nag for stale
rows and no "forever" value.

**`structural`** — a permanent carve-out that is correct by design, with no expiry.
These are the exclusions that used to be hard-coded into the test SQL, where nobody
could see them without opening the file. Two rows arrived this way:

| test | carve-out | why |
|---|---|---|
| `sac_asset_code_matches_metadata_symbol` | XLM SAC `CAS3J7GY…OWMA` | publishes `native` as its SEP-41 symbol while staging rewrites `asset_code` to `XLM` |
| `token_transfers_no_negative_circulating_supply` | `CB4PO24U…34E4` | non-compliant custom token that burns more than it mints; outside our control |

A structural row still needs a `reason`, and it is still validated — the point is
that it is visible and reviewable in one place, not that it is unchecked.

## Adding an exception

1. Add a row to `seeds/public_test_exceptions.csv`. Every column is described in
   `seeds/public_test_exceptions.yml`.
2. Scope it as tightly as the failure really is:
   - name an `entity_key` (contract, batch, table…) so only those rows are forgiven
   - add `day_from`/`day_to` when the failure is about specific days
   - leave `entity_key` empty only to suppress the test wholesale, and pair that
     with a short `expires_on`
3. Run `dbt seed --select public_test_exceptions` wherever the tests run, before the
   next test run. Until the seed has been loaded at least once, the wired tests fail
   with `Table … public_test_exceptions was not found` — run the seed, not a
   rollback.

## What each test can be scoped by

Every singular test in `tests/` is wired. `entity_column` must be one of the values
below; the day column is what a `day_from`/`day_to` range is compared against.

| `target_key` | `entity_column` | day scope |
|---|---|---|
| `bucketlist_db_size_check` | none | `date(closed_at)` of the ledger |
| `eho_by_ops` | `batch_id` | `date(batch_run_date)` |
| `int_token_transfer_enrichment_amount_matches_current_metadata` | `contract_id` | the day compared |
| `ledger_sequence_increment` | `ledger_id`, `batch_id` | `date(closed_at)` |
| `no_missing_days_in_snapshot` | `table_name` | first day of the gap |
| `no_missing_ledgers` | `table_name` | `date(closed_at)` of the gap |
| `num_txns_and_ops` | `batch_id` | `date(closed_at)` |
| `sac_asset_code_matches_metadata_symbol` | `contract_id` | none — current-state metadata |
| `token_transfers_no_negative_circulating_supply` | `contract_id` | none — aggregates all history |

The entity columns are alternatives, not a composite key: a row names one of them.

## Wiring a new test

Row-scoped exceptions only work for tests whose SQL we author, and whose predicate
can be appended to a final `where`. To wire one:

1. register it in `test_exception_targets()` in `macros/test_exceptions.sql`, naming
   the columns an exception may be scoped by and whether the test exposes a data day
2. call `exclude_test_exceptions()` in the test's final `where`, mapping each
   registered column name to the SQL expression that produces it

`tests/test_exceptions_valid.sql` validates rows against that registry, so a
mistyped `entity_column` fails loudly instead of quietly forgiving nothing. It is
itself deliberately not wired — excepting the validator would let a malformed row
silence the check that catches it.

The generic tests in `tests/generic/` (`recency`, `incremental_not_null`,
`incremental_unique`, …) are not wired. They run once per model, so a row would have
to name the model as well as the test, which this registry does not model yet. That
is the natural next step, and it is what would let a consumer of this package except
a single stale table's `recency` failure without deleting the test.

## Relationship to stellar-dbt

`stellar-dbt` installs this package and has its own `test_exceptions` seed for its
own tests, with the same schema. The two are deliberately separate tables:

- each repo's validator checks its own registry, so a shared table would make each
  one flag the other's rows as unregistered
- an exception lives in the same repo as the test it excepts, so they are reviewed
  together

Because `stellar-dbt` disables this package's seeds wholesale
(`seeds: stellar_dbt_public: +enabled: false`), it must re-enable this one seed for
the wired tests to resolve.
