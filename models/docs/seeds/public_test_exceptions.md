[comment]: < Public Test Exceptions -

{% docs public_test_exceptions %}
Known, accepted data-quality test failures, so pipelines stop alerting on situations we have already triaged. One row per exception. Read by `exclude_test_exceptions` (macros/test_exceptions.sql), which the registered singular tests append to their final `where`, and validated by tests/test_exceptions_valid.sql.
An exception is scoped, not a blanket disable: leaving `entity_key` empty suppresses the whole test, but naming an `entity_key` (and optionally a day range) forgives only those rows, so the same test still alerts on anything new.
`exception_kind` splits the table in two. A `temporary` row is an accepted failure and needs an `expires_on`; when it passes, the exception stops applying and the underlying test starts failing again, which is the review mechanism. A `structural` row is a permanent carve-out that is correct by design and carries no expiry -- these are the exclusions that used to be hard-coded into the test SQL, where nobody could see them without reading the file.
{% enddocs %}

{% docs public_test_exceptions__target_kind %}
What `target_key` names. Only `singular` (a singular test in tests/) is supported; the generic tests in tests/generic/ run once per model, so a row would have to name the model too.
{% enddocs %}

{% docs public_test_exceptions__exception_kind %}
`temporary` for an accepted failure we expect to fix, which requires `expires_on`; `structural` for a permanent carve-out that is correct by design, which must leave `expires_on` empty.
{% enddocs %}

{% docs public_test_exceptions__target_key %}
Name of the test the exception applies to, as registered in `test_exception_targets`. Never an auto-generated test node name -- those change whenever the test's arguments change.
{% enddocs %}

{% docs public_test_exceptions__entity_column %}
Which of the target's columns `entity_key` matches, e.g. `contract_id`. Must be a column the target registers. Empty only when `entity_key` is also empty.
{% enddocs %}

{% docs public_test_exceptions__entity_key %}
The value to except, matched exactly (no wildcards). Empty suppresses every failing row of the target, which is why such rows want a short `expires_on`.
{% enddocs %}

{% docs public_test_exceptions__day_from %}
First data day the exception covers, inclusive. Empty means all days. Only for targets registered with `allows_day_scope`.
{% enddocs %}

{% docs public_test_exceptions__day_to %}
Last data day the exception covers, inclusive. Empty means all days. Only for targets registered with `allows_day_scope`.
{% enddocs %}

{% docs public_test_exceptions__expires_on %}
Last day the exception applies, inclusive. Required for `temporary` and forbidden for `structural`. A null on a temporary row never matches, so a malformed row keeps alerting rather than silently forgiving forever.
{% enddocs %}

{% docs public_test_exceptions__reason %}
Why this failure is accepted, or why it is correct by design. Required. The pipeline does not care, but whoever reviews the table in three weeks does.
{% enddocs %}

{% docs public_test_exceptions__owner %}
Person or rotation accountable for the exception. Required.
{% enddocs %}

{% docs public_test_exceptions__ticket %}
Issue number tracking the underlying problem, without the `#`. Empty for structural carve-outs.
{% enddocs %}

{% docs public_test_exceptions__created_on %}
Day the exception was added, for review cadence.
{% enddocs %}
