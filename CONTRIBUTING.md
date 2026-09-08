# Contributing to stellar-dbt-public

Thanks for taking the time to improve stellar-dbt-public!

The following is a set of guidelines for contributions and may change over
time. Feel free to suggest improvements to this document in a pull request.

Start with the [Stellar Contribution Guide](https://github.com/stellar/.github/blob/master/CONTRIBUTING.md),
which applies to every Stellar project. For instructions on setting up the
project and running models and tests, see [DEVELOPING.md](DEVELOPING.md).

## Table of Contents

- [Branches](#branches)
- [Commit messages](#commit-messages)
- [Pull requests](#pull-requests)
- [Issues](#issues)
- [Releases](#releases)
- [SQL style](#sql-style)
- [Model conventions](#model-conventions)
- [Documentation](#documentation)
- [Security](#security)

## Branches

Before creating a branch it is important to know whether your change is a
release (breaking changes), a feature (functionality) or a patch (a bug fix).
With that information, name your branch like this:

- `major/<branch-name>`
- `minor/<branch-name>`
- `patch/<branch-name>`

If the branch already exists, rename it _before opening the pull request_.

The prefix is not just a convention: the release workflow reads it to decide
which part of the version to increment when your pull request merges. See
[Releases](#releases).

## Commit messages

- Use the present tense ("Add model" not "Added model").
- Use the imperative mood ("Move filter to..." not "Moves filter to...").
- Keep the subject line short and put context in the body.

## Pull requests

Open pull requests against `master`, or against the active `release*` branch if
the change belongs to a release already in flight.

The [pull request template](.github/pull_request_template.md) asks you to fill
in **What**, **Why**, and **Known limitations**. The "Why" matters most — include
enough context that a reviewer who has not seen the issue can follow the change.

- Keep scope narrow. Aim for something a reviewer can get through in about 20
  minutes; break bigger work into a series of pull requests.
- Do not mix refactoring with feature work. Refactoring pull requests touch far
  more code and get reviewed in less detail, so keep them separate.
- Add tests for new models and for the behavior a fix restores. A new mart model
  needs at least a uniqueness and a not-null test on its key.
- Run `pre-commit run --all-files` before pushing, and fix everything it
  reports.
- Say in the description whether the change alters existing output. A model
  whose columns or grain change is a breaking change for downstream consumers,
  and belongs on a `major/` branch.
- Update [DEVELOPING.md](DEVELOPING.md) or the [README](README.md) when you
  change how the project is set up, run, or laid out.

## Issues

- Label issues with `bug` if they are clearly a bug, and `feature request` if
  they are a feature request.
- For a data issue, include the model name, the dates or ledger range affected,
  and the query that shows the problem.

## Releases

This project is consumed as a dbt package, so every merge is a release.
Merging a pull request into `master` tags a new version and publishes a GitHub
release automatically. The version bump comes from your **branch prefix**:

| Branch prefix | Version bump | Use for                                         |
| ------------- | ------------ | ----------------------------------------------- |
| `major/`      | major        | Incompatible changes                            |
| `minor/`      | minor        | New functionality, backward compatible          |
| anything else | patch        | Backward-compatible bug fixes and documentation |

Note that a branch with no recognized prefix still produces a patch release, so
a breaking change on a mis-named branch gets an incorrect version. Rename the
branch before opening the pull request.

Because downstream projects pin this package by tag in their `packages.yml`,
merging here does not by itself ship your change to any consumer. A consumer
picks it up only after bumping its pin and running `dbt deps`.

## SQL style

- SQL is linted by [sqlfluff](https://docs.sqlfluff.com/) using the BigQuery
  dialect and the dbt templater. The rules live in [.sqlfluff](.sqlfluff).
- The `CI Linting` check runs `diff-quality` over the lines your branch changed
  and fails below a score of 95. It scores only your changed lines, so a file
  with pre-existing violations can pass while your new lines fail. Run
  `sqlfluff lint` on the files you touched before pushing.
- Reference other models with `{{ ref('model_name') }}` and raw tables with
  `{{ source('source_name', 'table_name') }}`, never with a hardcoded
  `project.dataset.table`.

## Model conventions

- Put the model in the right layer, and follow that layer's rules. See
  [Project structure](DEVELOPING.md#project-structure).
- Prefix staging models `stg_` and intermediate models `int_`, and match the
  naming of the models already in that directory: staging models are named for
  the source table they read (`stg_history_transactions`), and intermediate
  models use `int_<subject>__<detail>` when a subject has several models
  (`int_account_balances__trustlines`). Mart models are named for the entity
  they describe, with no prefix.
- Every model gets a co-located `.yml` of the same name, with a description for
  the model and for each of its columns. Marts additionally require every
  column to be described — an undescribed mart column is a review comment, and
  the project evaluator check tracks documentation coverage.
- Reuse an existing doc block for a column that already means the same thing
  elsewhere, rather than writing a new description. See
  [Documentation](#documentation).
- Prefer the project's date-scoped generic tests
  (`incremental_not_null`, `incremental_unique`, and friends in
  `tests/generic/`) over the stock dbt equivalents on incremental models, so a
  test checks the batch window rather than scanning the whole table.
- Do not disable a test to silence a known, accepted failure. Add a row to
  `seeds/public_test_exceptions.csv` instead, and read
  [docs/test_exceptions.md](docs/test_exceptions.md) first.

## Documentation

- Shared column descriptions live in `models/docs/universal.md` and are
  referenced as `{{ doc('column_name') }}`. Domain-specific blocks live in
  `models/docs/sources/`, `models/docs/intermediate/`, `models/docs/marts/`, and
  `models/docs/snapshots/`.
- Setup, running, testing, and layer guidance belong in
  [DEVELOPING.md](DEVELOPING.md).
- Contribution process, style, and release mechanics belong here.
- The published docs site is regenerated from `master` on every merge, so a
  missing description ships as a gap in public documentation.

## Security

This repository is **excluded** from the Stellar bug bounty program; see
[SECURITY.md](SECURITY.md). Please still avoid opening a public issue for a
suspected vulnerability — follow the
[Stellar security policy](https://github.com/stellar/.github/blob/master/SECURITY.md)
instead.
