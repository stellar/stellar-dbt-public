# Documenting models and columns

Every model, source table and column carries a description, published to the dbt docs site on
every merge to `master` (`.github/workflows/dbt-docs-website.yml`).

- [The rule](#the-rule)
- [Where a block lives, and what to call it](#where-a-block-lives-and-what-to-call-it)
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

and the text lives in a `.md` under `models/docs/`:

```markdown
{% docs asset_code %}
The 4 or 12 character code representation of the asset on the network.
{% enddocs %}
```

No allowlist, no exception file, no threshold to tune. `scripts/docs_lint.py check` enforces it
and runs in pre-commit.

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
a block between files is always safe. Placement is convention, not enforced;
`docs_lint.py report` shows how many tables use each block if you want to check whether
something has outgrown its home.

## Adding a column

1. Add the column to the model's `.yml` alongside its tests.
2. Look for an existing block: `grep -rn "{% docs <column_name> %}" models/docs/`
3. If one exists, read its text and confirm it describes your column. If it does not, write a
   new block named `<model>__<column>`.
4. Otherwise write a block in the model's mirror `.md`.
5. Run `docs_lint.py check`.

## Running the linter

No warehouse connection or credentials needed; it reads the yml and md files directly.

```bash
./venv/bin/python scripts/docs_lint.py check     # the gate; also runs in pre-commit
./venv/bin/python scripts/docs_lint.py report    # diagnostics, never fails a build
```

`check` fails on exactly three things: an inline description, a yml that will not parse (the
rule cannot be applied to a file that cannot be read), and two files defining the same block
name (dbt cannot resolve a duplicate).

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

Twenty-one references in this repo were wrong this way, thirteen of them publishing incorrect
text. They come from copying a neighbouring line and cluster on paired columns: `asset_a` /
`asset_b`, `read_bytes` / `write_bytes`, `batch_id` / `batch_run_date`.

This is a code review responsibility. When reviewing a description change, read the block that
is referenced rather than trusting its name. The last section of `docs_lint.py report` helps: a
column that disagrees with itself inside one table family is nearly always one of these.

## Proving a change is docs-neutral

Moving blocks between files should not change a single rendered description. Prove it:

```bash
git stash && ./venv/bin/python scripts/docs_lint.py snapshot --out /tmp/before.json
git stash pop && ./venv/bin/python scripts/docs_lint.py snapshot --out /tmp/after.json
./venv/bin/python scripts/docs_lint.py diff /tmp/before.json /tmp/after.json
```

A pure relocation must print `0 differences`; a text change must print exactly what you meant
to change. Paste that output into the PR: it is the cheapest way to show a reviewer that a large
diff is safe.

The snapshot is trustworthy because the resolver is checked against dbt itself with
`docs_lint.py validate-manifest` (expect `MISMATCHED: 0`), which needs a `target/manifest.json`
from `dbt parse` or `dbt docs generate`.

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
