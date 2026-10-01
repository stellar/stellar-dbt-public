<!-- If you're making a doc PR or something tiny where the below is irrelevant, delete this
template and use a short description, but in your description aim to include both what the
change is, and why it is being made, with enough context for anyone to understand. -->

<details>
  <summary>PR Checklist</summary>

### PR Structure

- [ ] This PR has reasonably narrow scope (if not, break it down into smaller PRs).
- [ ] This PR avoids mixing refactoring changes with feature changes (split into two PRs
      otherwise).
- [ ] This PR's title starts with the jira ticket associated with the PR.

### Thoroughness

- [ ] This PR adds tests for the most critical parts of the new functionality or fixes.
- [ ] I've updated the docs and README with the added features, breaking changes, new instructions on how to use the repository.
- [ ] If this PR touches column or model descriptions, they live in doc blocks under `models/docs/` rather than inline in the `.yml`, and I read the text of every block I referenced rather than trusting its name (see [docs/documentation.md](../docs/documentation.md)).

### Release planning

- [ ] I've decided if this PR requires a new major/minor/patch version accordingly to
    [semver](https://semver.org/), and I've changed the name of the BRANCH to major/* , minor/* or patch/* .
</details>

### What

[TODO: Short statement about what is changing.]

### Why

[TODO: Why this change is being made. Include any context required to understand the why.]

### Known limitations

[TODO or N/A]

### Backfill readiness

<!-- Delete this section if the PR doesn't add a model or change a model's materialization,
incremental strategy, partition_by, or batch_start_date / batch_end_date filters. -->

| Model | Full-refresh time | Materialization / strategy | How measured |
|---|---|---|---|
| `model_name` | e.g. 42 min | e.g. microbatch (month, copy_partitions) | e.g. dev-hubble run on YYYY-MM-DD, or estimate |

- [ ] The strategy matches the full-refresh time: < 5 min → `table` · 5–30 min → `incremental` + `insert_overwrite` · > 30 min → `incremental` + `microbatch`
      (any exception is explained above, e.g. kept as `table` because the daily full rebuild is cheap)
- [ ] No `merge` incremental strategy (allowed only for snapshots and `*_current` models)
- [ ] If the model is partitioned and holds data from genesis (2015), it filters on `batch_end_date`, including on the full-refresh path
