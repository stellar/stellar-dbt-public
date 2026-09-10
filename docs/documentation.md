# Documenting models and columns

Every model, source table and column carries a description, published to the dbt docs site on
every merge to `master` (`.github/workflows/dbt-docs-website.yml`).

- [The rule](#the-rule)
- [Where a block lives, and what to call it](#where-a-block-lives-and-what-to-call-it)
- [Adding a column](#adding-a-column)
- [Running the linter](#running-the-linter)
- [Matching the built table](#matching-the-built-table)
- [What the linter does not catch](#what-the-linter-does-not-catch)
- [Proving a change is docs-neutral](#proving-a-change-is-docs-neutral)
- [File conventions](#file-conventions)
- [Relationship to stellar-dbt](#relationship-to-stellar-dbt)

## The rule

**Descriptions live in doc blocks, never inline in yml.** The yml holds a reference:

```yaml
- name: asset_code
  description: '{{ doc("asset_code") }}'
```

and the text lives in a `.md` under `models/docs/`:

```markdown
{% docs asset_code %}
The 4 or 12 character code representation of the asset on the network.
{% enddocs %}
```

No allowlist, no per-description exception, no way to defer a path, no threshold to tune.
`scripts/docs_lint.py check` enforces it and runs in pre-commit.

## Where a block lives, and what to call it

`models/docs/` mirrors `models/`: a column on `models/marts/trade_agg.sql` is documented in
`models/docs/marts/trade_agg.md`. Create the mirror file if it does not exist.

A definition that **unrelated tables** share goes in `models/docs/universal.md` instead, named
after the bare column (`asset_code`, `batch_run_date`, `closed_at`). A column that merely flows
`sources/` -> `staging/` -> `marts/` touches several files but is still one table's column, so
it stays in that table's mirror file.

A definition specific to one model is named `<model>__<column>`, for example
`int_tvl_trustlines__asset_code` because that column carries non-XLM TVL only. Use the scoped
form whenever a column's meaning differs from the shared block of the same name, even slightly.
`amount_raw` (i128 base units) and `amount` (decimals applied) are different concepts and get
different blocks.

Block names are globally unique across the project and resolve by name, not by file, so moving
a block between files is always safe.

`check` enforces the root: a definition this repo owns must live somewhere under `models/docs/`.
Which file it lands in inside that root is convention, not enforced, so the mirror rule above is
guidance rather than a gate. `docs_lint.py report` shows how many tables use each block if you
want to check whether something has outgrown its home.

## Adding a column

1. Add the column to the model's `.yml` alongside its tests.
2. Look for an existing block: `grep -rn "{% docs <column_name> %}" models/docs/`
3. If one exists, read its text and confirm it describes your column. If it does not, write a
   new block named `<model>__<column>`.
4. Otherwise write a block in the model's mirror `.md`.
5. Run `docs_lint.py check`.
6. If the SQL changed too, run `docs_lint.py columns` against a catalog of your dev build, or let
   CI do it. The yml column list must match the built table.

## Running the linter

No warehouse connection or credentials needed; it reads the yml and md files directly.

```bash
./venv/bin/python scripts/docs_lint.py check     # the gate; also runs in pre-commit
./venv/bin/python scripts/docs_lint.py report    # diagnostics, never fails a build
```

`check` requires that the whole value of a `description:` is one `doc()` call naming a block that
exists, so it fails on inline text, on text wrapped around a reference
(`see {{ doc("x") }} for detail`), on an empty description, on two references in one value, and
on a name that is not defined anywhere. It also fails on a yml that will not parse (the rule
cannot be applied to a file that cannot be read) on two files defining the same block name
(dbt cannot resolve a duplicate), and on a definition this repo owns that sits outside
`models/docs/`, which is how a definition drifts somewhere nobody thinks to look.

`check` also holds the yml to three completeness rules it can decide offline: every model, seed
and snapshot file has a yml entry; every declared column carries a description; and no column is
declared twice under one resource (yaml keeps the last entry, so the first description is silently
dropped and dbt does not warn). A resource an installed package already declares counts as declared:
the `dbt_project_evaluator_exceptions` seed overrides the package's seed of the same name, and dbt
refuses a second yml entry for it.

**Macro and argument descriptions are out of scope.** They document one macro's signature, so
there is nothing to factor out, and moving them into `models/docs/` would only put a macro's API
docs further from the macro.

`report` lists orphan blocks, how many tables use each block, and any column name that resolves
to more than one description.

## What the linter does not catch

**A `doc()` that points at the wrong block.** The rule checks that a description *is* a
reference, not that the reference is *correct*, so both of these pass:

```yaml
- name: asset_b_type
  description: '{{ doc("asset_a_type") }}'      # renders "the sold asset", not "the bought asset"
- name: operation_id
  description: '{{ doc("transaction_id") }}'    # renders "a unique identifier for this transaction"
```

Both of those are live in this repo right now, along with nineteen more. They come from copying
a neighbouring line and cluster on paired columns: `asset_a` / `asset_b`, `read_bytes` /
`write_bytes`, `batch_id` / `batch_run_date`. Repairing them changes published text, so it is
tracked separately in #326 and deliberately not part of the change that added this linter.

This is a code review responsibility. When reviewing a description change, read the block that
is referenced rather than trusting its name. The last section of `docs_lint.py report` helps: a
column that disagrees with itself inside one table family is nearly always one of these.

## Matching the built table

The rules above cannot see a column the yml never mentions, or a yml entry naming a column the
table no longer has. Both publish silently: the docs site renders the live column with an empty
description, or describes a column that does not exist, and `persist_docs` writes nothing onto the
BigQuery column. dbt warns about neither.

The only witness to what a table actually contains is dbt's catalog, so this check cannot run
offline and is not in pre-commit:

```bash
dbt docs generate                                                    # writes target/catalog.json
./venv/bin/python scripts/docs_lint.py columns                       # compare yml column lists with it
./venv/bin/python scripts/docs_lint.py columns --strict --max-age 1  # what CI runs
```

`columns` reports, per resource, the live top-level columns with no yml entry (**missing**), the
yml entries naming no live column (**stale**), and first-level struct fields with no entry
(**nested**, informational). `--strict` exits 1 on missing or stale; nested never fails. A resource
the catalog does not cover is counted and skipped, so a partial catalog from a PR build is fine.
`--max-age` refuses a catalog older than the given hours, because a stale catalog proves nothing.
`--package all` compares every package in the catalog, reading an installed package's yml from
`dbt_packages/`.

**Nested fields.** Document every top-level column. Document first-level struct fields where the
table's yml already follows that pattern (the `details.*` entries on the history_operations source,
for example). Never document recursive paths such as `claimants.predicate.and.or.abs_before`; the
top-level column's block describes the structure.

**When you add, rename or drop a column in SQL, change the yml in the same PR.** A rename is one
missing plus one stale entry: fix both and keep the block. A dropped column is a stale entry: delete
it. A new column is a missing entry: follow [Adding a column](#adding-a-column).

Where it runs:

- `stellar-dbt` builds this project's models into their prod datasets, so the blocking check lives
  there: its `slim-ci` job runs `dbt docs generate` on the models a PR built and fails on missing or
  stale columns, and its master docs job reports the drift for both packages on every merge and
  uploads the prod `catalog.json` as a workflow artifact, so anyone can run `columns` against it
  without warehouse access. This repo's own docs job generates against a dataset that holds almost
  none of the built tables, so it cannot check anything yet.

## Proving a change is docs-neutral

Moving blocks between files should not change a single rendered description. Prove it:

```bash
git stash push --include-untracked   # -u matters: a new untracked .yml or .md
./venv/bin/python scripts/docs_lint.py snapshot --out /tmp/before.json
git stash pop
./venv/bin/python scripts/docs_lint.py snapshot --out /tmp/after.json
./venv/bin/python scripts/docs_lint.py diff /tmp/before.json /tmp/after.json
```

A pure relocation must print `0 differences`; a text change must print exactly what you meant
to change. Paste that output into the PR: it is the cheapest way to show a reviewer that a large
diff is safe.

The snapshot is trustworthy because the resolver is checked against dbt itself with
`docs_lint.py validate-manifest`, which needs a `target/manifest.json` from `dbt parse` or
`dbt docs generate`. It exits non-zero unless `MISMATCHED` is 0, nothing is unresolved, and every
description it could not compare is one an installed package patched in, which this repo cannot
see by design.

One thing that looks like it should work and does not: **a `doc()` call inside a doc block.** dbt
renders block bodies without the `doc` macro in scope and fails the parse with
`'doc' is undefined`, so a shared definition cannot be wrapped with a local qualifier. Write a
scoped `<model>__<column>` block with the full text instead.
## File conventions

- One `.md` per model or source table, mirroring the model's path. Where sibling models each
  need only a model-level description, one file for the group is fine (see
  `models/docs/intermediate/trades/int_trade_agg.md`).
- Open each file with a subject comment: `[comment]: < Trade Aggregations -`. Most files use
  exactly that form, dangling hyphen included; prefer it in new files.
- Split `universal.md` into subject files (`asset.md`, `ledger_state.md`, `batch.md`) at around
  60 to 80 blocks. Below that, one file is easier to search.
- `models/docs/sources/history_operations.md` holds 125 blocks and is the one file that is
  genuinely too large. Splitting it is tracked separately.

## Relationship to stellar-dbt

`stellar-dbt` installs this repo as a git package and references roughly 200 doc blocks defined
here. **Never rename or delete a block** without checking there first: a rename breaks its parse
and costs a `packages.yml` pin bump plus `dbt deps` to unwind. Moving a block between files is
safe.

To check before merging something risky, point `stellar-dbt`'s `packages.yml` at your branch and
run `dbt deps && dbt parse` there. A clean parse confirms every cross-repo reference resolves.

`scripts/docs_lint.py` is meant to be identical in both repos: it reads
the project name from `dbt_project.yml` rather than hardcoding it, so a change made here is
copied across verbatim rather than ported by hand.
