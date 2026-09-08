# Documenting models and columns

Every model, source table and column in this package carries a description, and those
descriptions are published to the dbt docs site on every merge to `master` (see
`.github/workflows/dbt-docs-website.yml`). This document is the process for writing them.

- [The one rule](#the-one-rule)
- [Where a doc block lives](#where-a-doc-block-lives)
- [Naming a doc block](#naming-a-doc-block)
- [Adding a column](#adding-a-column)
- [Adding a shared definition](#adding-a-shared-definition)
- [Running the linter](#running-the-linter)
- [Proving a change is docs-neutral](#proving-a-change-is-docs-neutral)
- [The two exception files](#the-two-exception-files)
- [File conventions](#file-conventions)
- [Relationship to stellar-dbt](#relationship-to-stellar-dbt)

## The one rule

**Never write the same description twice.** That is the whole point of doc blocks, and it is
what `scripts/docs_lint.py` enforces.

Concretely:

| Situation | What to write |
|---|---|
| The text is unique to this one column | An inline `description:`. This is correct, and a doc block for it would be indirection with nothing to reuse. |
| The same text belongs on 2+ columns or models | A doc block, referenced from each place with `'{{ doc("name") }}'` |
| A doc block already says what you were about to type | Reference the block. Do not paste its text. |
| The text is long, or needs markdown | A doc block, even if used once, because long prose in yml is hard to read |

This matches dbt's own guidance: `doc()` exists "as a way to reuse the same text in multiple
places", and inline descriptions are a first-class option for everything else.

There is deliberately **no allowlist** of files permitted to hold inline descriptions. A unique
inline description is not a violation, so there is nothing to grant an exception to.

## Where a doc block lives

Placement is decided by how many **distinct table families** reference the block. A family is
one table and all its variants: `src_trust_lines`, `stg_trust_lines`, `trust_lines_current` and
`trustlines_snapshot` are one family, not four.

| Families referencing the block | Home |
|---|---|
| 1 | that table's mirror file, e.g. `models/docs/sources/history_operations.md` |
| 2 to 3 | the primary table's mirror file |
| 4 or more | `models/docs/universal.md` |

Counting *files* instead of families is the trap. A column that flows
`sources/` -> `staging/` -> `intermediate/` -> `marts/` appears in four files and four
directories, but it is one table's column and belongs in that table's mirror file. Only a
definition that unrelated tables genuinely share, like `asset_code` or `batch_run_date`, earns
a place in `universal.md`.

`models/docs/` mirrors `models/`: a block for `models/marts/trade_agg.sql` goes in
`models/docs/marts/trade_agg.md`. If the mirror file does not exist yet, create it.

The linter enforces the 4+ end of this (rule R3). It does not enforce the 1 and 2-to-3 rows,
because a block in a slightly odd mirror file harms nobody; a shared definition with no obvious
home does.

## Naming a doc block

- **Shared definition**: the bare column name. `asset_code`, `batch_id`, `closed_at`.
- **Column-specific definition**: `<model>__<column>`, with a double underscore. For example
  `higlobe_transactions__amount`, because that column's amount is in whole units rather than
  stroops and so cannot reuse the universal `amount` block.

Use the scoped form whenever a column's meaning differs from the shared block of the same name,
even slightly. Two columns share a block only when they mean the same thing at the same grain.
`amount_raw` (i128 base units) and `amount` (decimals applied) are different concepts and get
different blocks.

Block names are **globally unique across the whole dbt project**, including the packages this
one is installed into. dbt errors on a duplicate name. The file a block lives in has no effect
on how `doc()` resolves it, so moving a block between files is always safe.

## Adding a column

1. Add the column to the model's `.yml` alongside its tests.
2. Search for an existing block before writing anything:

   ```bash
   grep -rn "{% docs <column_name> %}" models/docs/
   ```

3. If a block exists, read its text and confirm it actually describes your column. If it does,
   reference it. If it does not, write a new block named `<model>__<column>`.
4. If no block exists, decide by the table above: unique text goes inline; text you are about
   to repeat becomes a block.
5. Run the linter.

## Adding a shared definition

1. Write the block in `models/docs/universal.md` if 4+ table families will use it, otherwise in
   the primary table's mirror file.
2. Reference it from each `.yml`:

   ```yaml
   - name: asset_code
     description: '{{ doc("asset_code") }}'
   ```

3. Run the linter. If the block later spreads to a fourth family, R3 will tell you to move it.

## Running the linter

`scripts/docs_lint.py` needs no warehouse connection and no credentials. It reads the yml and
md files directly.

```bash
./venv/bin/python scripts/docs_lint.py check     # the gate; also runs in pre-commit
./venv/bin/python scripts/docs_lint.py report    # fanout, orphan blocks, divergent columns
```

The rules, and why each exists:

| Rule | Fails when | Why |
|---|---|---|
| R0 | A yml will not parse, or two files define the same block name | dbt would error on this anyway |
| R1 | The same description text is written inline 2+ times | The duplication doc blocks were adopted to prevent |
| R2 | A `doc()` names a block that does not exist | dbt would render an empty description |
| R3 | A block used by 4+ table families is not in `universal.md` | Keeps one obvious home for shared definitions. Also catches over-merging: a block spread very wide is usually one definition stretched over columns that differ |
| R4 | An inline description restates an existing block's text | The block is right there; reference it |
| R5 | A `doc()` names a block close to but not equal to the column name, when a block matching the column name exists | Catches a wrong-block copy-paste between paired columns |
| R7, R8 | An entry in an exception file no longer applies | Stops the exception files from rotting |

**R5 deserves a note**, because it is the rule with real teeth and no equivalent in dbt or
dbt-checkpoint. Paired columns get crossed by copy-paste, and the result looks almost right:
`asset_b_type` documented by the `asset_a_type` block ("the sold asset" instead of "the bought
asset"), or `soroban_resources_write_bytes` documented by the `read_bytes` block. Sixteen such
references existed in this repo and were shipping wrong text to the docs site. High similarity
between a column name and the block it references is a red flag, not a green light.

## Proving a change is docs-neutral

Moving blocks between files, or reorganising `models/docs/`, should not change a single rendered
description. Prove it rather than assuming it:

```bash
git stash && ./venv/bin/python scripts/docs_lint.py snapshot --out /tmp/before.json
git stash pop && ./venv/bin/python scripts/docs_lint.py snapshot --out /tmp/after.json
./venv/bin/python scripts/docs_lint.py diff /tmp/before.json /tmp/after.json
```

A pure relocation must print `0 differences`. A text change must print exactly the descriptions
you meant to change, and nothing else. Paste that output into the PR.

The snapshot is trustworthy because the resolver is checked against dbt itself:

```bash
./venv/bin/python scripts/docs_lint.py validate-manifest   # expect MISMATCHED: 0
```

This compares every statically resolved description against `target/manifest.json`, so it needs
a manifest to exist (`dbt parse` or `dbt docs generate`). It is the check that lets the rest of
the workflow skip dbt entirely.

## The two exception files

Both are for cases the linter cannot decide. **Every entry requires a written reason**, and a
reviewer should push back on one that lacks it.

**`scripts/docs_ref_ignore.txt`** silences a single R5 hit that is deliberate. Format
`<yml path>:<column>:<referenced block>`. Only add an entry after reading both block texts,
because R5's false positives and its true positives look identical from the outside. Current
entries are `assets_id` (a different identifier from the universal `asset_id` Farm Hash block)
and `op_transaction_id` (more specific than the bare `transaction_id` block).

**`scripts/docs_block_exceptions.txt`** parks a block that trips R3. Format
`<block name>  # reason`. Every current entry is a **known defect**, not an approved pattern:
each is one block stretched over columns that do not mean the same thing, waiting on a text fix
rather than a move. Clearing an entry changes published text, so do it in its own PR, never
inside a relocation.

## File conventions

- One `.md` per model or source table, mirroring the model's path under `models/docs/`.
- Each file opens with a comment line naming its subject: `[comment]: < Trade Aggregations -`.
  The majority of files use exactly that form, including the dangling hyphen. A handful use
  `[comment]: < Title >` or `[comment]: # (Title)`; prefer the majority form in new files.
- Blocks within a file are separated by a blank line.
- `models/docs/universal.md` holds only the 4+ family definitions. At around 60 to 80 blocks it
  should be split into subject files (`asset.md`, `ledger_state.md`, `batch.md`); below that,
  one file is easier to search.

## Relationship to stellar-dbt

`stellar-dbt` installs this repo as a git package and **references roughly 200 doc blocks
defined here** from its own yml. Two consequences:

- **Never rename or delete a doc block** without checking `stellar-dbt` first. A rename breaks
  its parse and costs a `packages.yml` pin bump plus `dbt deps` to unwind.
- Moving a block between files here is safe, because `doc()` resolves by name.

To verify before merging something risky: point `stellar-dbt`'s `packages.yml` at your branch,
then run `dbt deps && dbt parse` there. A clean parse confirms every cross-repo reference still
resolves.
