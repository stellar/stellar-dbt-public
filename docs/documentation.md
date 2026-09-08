# Documenting models and columns

Every model, source table and column in this package carries a description, and those
descriptions are published to the dbt docs site on every merge to `master` (see
`.github/workflows/dbt-docs-website.yml`). This document is the process for writing them.

- [The rule](#the-rule)
- [Where a doc block lives](#where-a-doc-block-lives)
- [Naming a doc block](#naming-a-doc-block)
- [Adding a column](#adding-a-column)
- [Running the linter](#running-the-linter)
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

and the text itself lives in a `.md` file under `models/docs/`:

```markdown
{% docs asset_code %}
The 4 or 12 character code representation of the asset on the network.
{% enddocs %}
```

That is the whole rule. There is no allowlist, no exception file, and no threshold to tune:
every `description:` in every properties yml is a `doc()` reference, and the repo is currently
at 2,331 of 2,331. `scripts/docs_lint.py check` enforces it, and it runs in pre-commit.

The point is that a description has one home. When the same column appears in a source, a
staging model and a mart, all three point at the same block, so the text cannot drift between
them and updating it is one edit.

## Where a doc block lives

`models/docs/` mirrors `models/`. A block used by one table goes in that table's mirror file:
a column on `models/marts/trade_agg.sql` is documented in `models/docs/marts/trade_agg.md`. If
the mirror file does not exist yet, create it.

A definition that **unrelated tables** genuinely share goes in `models/docs/universal.md`.
That is where `asset_code`, `batch_run_date`, `closed_at`, `account_id` and the other
cross-cutting columns live.

The distinction is unrelated tables, not several files. A column flowing
`sources/` -> `staging/` -> `intermediate/` -> `marts/` appears in four files and four
directories, but it is one table's column and belongs in that table's mirror file. Only
promote to `universal.md` when four or more distinct tables use the same definition.

This is convention rather than an enforced rule, because a block in a slightly odd mirror file
harms nobody. `scripts/docs_lint.py report` prints how many tables use each block if you want
to check whether something has outgrown its home.

## Naming a doc block

- **Shared definition**: the bare column name. `asset_code`, `batch_id`, `closed_at`.
- **Definition specific to one model**: `<model>__<column>`, double underscore. For example
  `int_tvl_trustlines__asset_code`, because that column carries non-XLM TVL only and so cannot
  reuse the universal `asset_code` text.

Use the scoped form whenever a column's meaning differs from the shared block of the same
name, even slightly. Two columns share a block only when they mean the same thing at the same
grain: `amount_raw` (i128 base units) and `amount` (decimals applied) are different concepts
and get different blocks.

Block names are **globally unique across the whole dbt project**, including the packages this
one is installed into, and dbt errors on a duplicate. The file a block lives in has no effect
on how `doc()` resolves it, so moving a block between files is always safe.

## Adding a column

1. Add the column to the model's `.yml` alongside its tests.
2. Look for an existing block before writing anything:

   ```bash
   grep -rn "{% docs <column_name> %}" models/docs/
   ```

3. If a block exists, **read its text** and confirm it actually describes your column. If it
   does, reference it. If it does not, write a new block named `<model>__<column>`.
4. If no block exists, write one in the model's mirror `.md` file.
5. Run the linter.

## Running the linter

`scripts/docs_lint.py` needs no warehouse connection and no credentials. It reads the yml and
md files directly.

```bash
./venv/bin/python scripts/docs_lint.py check     # the gate; also runs in pre-commit
./venv/bin/python scripts/docs_lint.py report    # diagnostics, never fails a build
```

`check` fails on three things, and only these three:

| Failure | Meaning |
|---|---|
| An inline description | The rule above. Move the text into a doc block. |
| A yml that will not parse | The rule cannot be applied to a file that cannot be read, so this is an error rather than a skip. |
| Two files defining the same block name | dbt cannot resolve a duplicate name and will error. |

`report` is read-only and worth a look when you are unsure where something belongs. It prints
orphan blocks, how many tables use each block, and any column name that resolves to more than
one description.

## What the linter does not catch

Deliberately narrow scope has a cost, and it is worth knowing where it falls:

**A `doc()` that points at the wrong block.** The linter checks that a description *is* a
reference, not that the reference is *correct*. Both of these pass `check`:

```yaml
- name: asset_b_type
  description: '{{ doc("asset_a_type") }}'      # renders "the sold asset", not "the bought asset"

- name: operation_id
  description: '{{ doc("transaction_id") }}'    # renders "a unique identifier for this transaction"
```

Twenty-one references in this repo were wrong this way, thirteen of them publishing incorrect
text to the docs site. They come from copying a neighbouring line, and they cluster on paired
columns: `asset_a` / `asset_b`, `read_bytes` / `write_bytes`, `batch_id` / `batch_run_date`.

So this is a **code review responsibility, not a linter one**. When reviewing a description
change, read the block that is referenced, not just the reference. `docs_lint.py report`
helps: its last section lists every column name that resolves to more than one description,
and a column that disagrees with itself inside a single table family is nearly always one of
these.

## Proving a change is docs-neutral

Moving blocks between files, or reorganising `models/docs/`, should not change a single
rendered description. Prove it rather than assuming it:

```bash
git stash && ./venv/bin/python scripts/docs_lint.py snapshot --out /tmp/before.json
git stash pop && ./venv/bin/python scripts/docs_lint.py snapshot --out /tmp/after.json
./venv/bin/python scripts/docs_lint.py diff /tmp/before.json /tmp/after.json
```

A pure relocation must print `0 differences`. A text change must print exactly the descriptions
you meant to change, and nothing else. Paste that output into the PR: it is the cheapest way to
show a reviewer that a large diff is safe.

The snapshot is trustworthy because the resolver is checked against dbt itself:

```bash
./venv/bin/python scripts/docs_lint.py validate-manifest   # expect MISMATCHED: 0
```

This compares every statically resolved description against `target/manifest.json`, so it needs
a manifest to exist (`dbt parse` or `dbt docs generate`). It is what lets the rest of this
workflow skip dbt entirely.

## File conventions

- One `.md` per model or source table, mirroring the model's path under `models/docs/`. Where
  a group of sibling models each need only a model-level description, one file for the group is
  fine (see `models/docs/intermediate/trades/int_trade_agg.md`).
- Each file opens with a comment line naming its subject: `[comment]: < Trade Aggregations -`.
  Most files use exactly that form, including the dangling hyphen. A few use
  `[comment]: < Title >` or `[comment]: # (Title)`; prefer the majority form in new files.
- Blocks within a file are separated by a blank line.
- `models/docs/universal.md` holds the cross-cutting definitions. At around 60 to 80 blocks it
  should be split into subject files (`asset.md`, `ledger_state.md`, `batch.md`); below that,
  one file is easier to search.
- `models/docs/sources/history_operations.md` currently holds 125 blocks and is the one file
  that is genuinely too large. Splitting it is tracked separately.

## Relationship to stellar-dbt

`stellar-dbt` installs this repo as a git package and **references roughly 200 doc blocks
defined here** from its own yml. Two consequences:

- **Never rename or delete a doc block** without checking `stellar-dbt` first. A rename breaks
  its parse and costs a `packages.yml` pin bump plus `dbt deps` to unwind.
- Moving a block between files here is safe, because `doc()` resolves by name.

To verify before merging something risky: point `stellar-dbt`'s `packages.yml` at your branch,
then run `dbt deps && dbt parse` there. A clean parse confirms every cross-repo reference still
resolves.
