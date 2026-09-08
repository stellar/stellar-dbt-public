# stellar-dbt-public

A public [dbt](https://docs.getdbt.com/docs/introduction) project that
transforms Stellar network history into analytics-ready tables in BigQuery.

It takes the raw ledger, transaction, operation, and state data extracted by
[stellar-etl](https://github.com/stellar/stellar-etl) and models it into the
staging, intermediate, mart, and snapshot layers that back
[Hubble](https://developers.stellar.org/docs/data/analytics/hubble), the
Stellar Development Foundation's public analytics dataset.

## Documentation

| Document                                           | Contents                                                                   |
| -------------------------------------------------- | -------------------------------------------------------------------------- |
| This README                                        | What the project is and how to consume its output                          |
| [DEVELOPING.md](DEVELOPING.md)                     | Local setup, running models and tests, project layout, and CI              |
| [CONTRIBUTING.md](CONTRIBUTING.md)                 | Branch naming, pull request etiquette, release mechanics, and SQL style    |
| [docs/snapshot.md](docs/snapshot.md)               | The custom snapshot materialization, its macros, and how to repair one     |
| [docs/test_exceptions.md](docs/test_exceptions.md) | How accepted test failures are recorded                                    |
| [SECURITY.md](SECURITY.md)                         | Bug bounty scope                                                           |

For the Stellar network itself and for guidance on querying the public dataset,
see the [Stellar developer documentation](https://developers.stellar.org/).

## Querying the data

Most people do not need to run this project. The tables it builds are published
in the public `crypto-stellar` BigQuery project and can be queried directly. See
the [Hubble documentation](https://developers.stellar.org/docs/data/analytics/hubble)
for the datasets, access instructions, and cost guidance.

## Project layout

| Layer        | Location               | Purpose                                                  |
| ------------ | ---------------------- | -------------------------------------------------------- |
| Sources      | `models/sources/`      | Declarations of the raw tables the project reads         |
| Staging      | `models/staging/`      | Source preprocessing: selection, renaming, casting       |
| Intermediate | `models/intermediate/` | Joins, aggregations, and business logic                  |
| Marts        | `models/marts/`        | Final analytics-ready dimensional models                 |
| Snapshots    | `snapshots/`           | SCD Type-2 history with `valid_from` / `valid_to`        |

`macros/` holds reusable SQL, including the custom `incremental_snapshot`
materialization. `tests/` holds singular tests and this project's generic
tests, `seeds/` small CSVs loaded as tables, and `models/docs/` the shared doc
blocks behind the published column descriptions.

[DEVELOPING.md](DEVELOPING.md#project-structure) describes what belongs in each
layer.

## Using this project as a dbt package

This project is published as a dbt package, tagged on every merge to `master`.
To depend on it, add it to your `packages.yml` pinned to a tag:

```yaml
packages:
  - git: "https://github.com/stellar/stellar-dbt-public.git"
    revision: <tag>
```

Then run `dbt deps`. Because the pin is by tag, a release here reaches your
project only once you bump that revision.

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) for branch
naming, pull request expectations, and release mechanics, and
[DEVELOPING.md](DEVELOPING.md) to get a local environment running.

---

> **Note:** This repository is not in scope for the Stellar Development
> Foundation bug bounty program. Vulnerabilities found in this repo are not
> eligible for rewards.
