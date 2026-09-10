#!/usr/bin/env python
"""Unit tests for scripts/docs_lint.py.

Stdlib only (unittest + tempfile), so they run anywhere the linter runs:

    python scripts/test_docs_lint.py

Each test builds a throwaway dbt project layout in a temp dir and drives the
real CLI through `docs_lint.main`, so what is asserted is what a contributor
sees. Like docs_lint.py itself this file is identical in stellar-dbt and
stellar-dbt-public; copy it across verbatim.
"""

from __future__ import annotations

import contextlib
import datetime
import io
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import docs_lint  # noqa: E402


PROJECT = "fixture_pkg"


def _write(root, rel, text):
    path = os.path.join(root, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)
    return path


def _iso(hours_ago=0):
    when = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=hours_ago)
    return when.strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def _catalog(root, nodes, sources=None, hours_ago=0, filename="catalog.json"):
    """Write a dbt-style catalog.json. `nodes`: unique_id -> [column names]."""
    def entry(uid, cols):
        return {
            "unique_id": uid,
            "metadata": {"type": "table", "schema": "s", "name": uid.split(".")[2]},
            "columns": {c: {"type": "STRING", "index": i, "name": c} for i, c in enumerate(cols)},
            "stats": {},
        }
    data = {
        "metadata": {"generated_at": _iso(hours_ago), "dbt_version": "1.12.4"},
        "nodes": {uid: entry(uid, cols) for uid, cols in nodes.items()},
        "sources": {uid: entry(uid, cols) for uid, cols in (sources or {}).items()},
        "errors": None,
    }
    return _write(root, filename, json.dumps(data))


def run(argv):
    """Run the CLI, returning (exit_code, stdout)."""
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        try:
            code = docs_lint.main(argv)
        except SystemExit as exc:  # argparse errors
            code = exc.code
    return code, out.getvalue()


class Fixture(unittest.TestCase):
    """A minimal project: one documented model, one block, everything clean."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name
        _write(self.root, "dbt_project.yml", "name: %s\nversion: '1.0'\n" % PROJECT)
        _write(self.root, "models/marts/orders.sql", "select 1 as order_id, 2 as amount\n")
        _write(self.root, "models/docs/marts/orders.md",
               "{% docs orders %}Orders.{% enddocs %}\n"
               "{% docs order_id %}The id.{% enddocs %}\n"
               "{% docs amount %}The amount.{% enddocs %}\n")
        self.yml = _write(self.root, "models/marts/orders.yml", self.orders_yml())

    def tearDown(self):
        self.tmp.cleanup()

    @staticmethod
    def orders_yml(columns=None):
        columns = columns if columns is not None else [
            ("order_id", '\'{{ doc("order_id") }}\''),
            ("amount", '\'{{ doc("amount") }}\''),
        ]
        lines = ["version: 2", "models:", "  - name: orders",
                 "    description: '{{ doc(\"orders\") }}'", "    columns:"]
        for name, desc in columns:
            lines.append("      - name: %s" % name)
            if desc is not None:
                lines.append("        description: %s" % desc)
        return "\n".join(lines) + "\n"

    def check(self):
        return run(["--root", self.root, "check"])

    def columns(self, *extra):
        return run(["--root", self.root, "columns", "--catalog",
                    os.path.join(self.root, "catalog.json"), *extra])


class CheckExistingRule(Fixture):
    def test_clean_project_passes(self):
        code, out = self.check()
        self.assertEqual(code, 0, out)
        self.assertIn("clean", out)

    def test_inline_description_fails(self):
        _write(self.root, "models/marts/orders.yml",
               self.orders_yml([("order_id", "'{{ doc(\"order_id\") }}'"), ("amount", "The amount")]))
        code, out = self.check()
        self.assertEqual(code, 1)
        self.assertIn("inline description", out)


class CheckColumnCoverage(Fixture):
    def test_column_without_description_key_fails(self):
        _write(self.root, "models/marts/orders.yml",
               self.orders_yml([("order_id", "'{{ doc(\"order_id\") }}'"), ("amount", None)]))
        code, out = self.check()
        self.assertEqual(code, 1)
        self.assertIn("amount", out)
        self.assertIn("no description", out)

    def test_duplicate_column_declaration_fails(self):
        _write(self.root, "models/marts/orders.yml",
               self.orders_yml([("order_id", "'{{ doc(\"order_id\") }}'"),
                                ("amount", "'{{ doc(\"amount\") }}'"),
                                ("amount", "'{{ doc(\"order_id\") }}'")]))
        code, out = self.check()
        self.assertEqual(code, 1)
        self.assertIn("amount", out)
        self.assertIn("twice", out)

    def test_model_sql_without_yml_entry_fails(self):
        _write(self.root, "models/marts/refunds.sql", "select 1 as refund_id\n")
        code, out = self.check()
        self.assertEqual(code, 1)
        self.assertIn("refunds", out)
        self.assertIn("no yml entry", out)

    def test_seed_csv_without_yml_entry_fails(self):
        _write(self.root, "seeds/countries.csv", "code,name\nUS,United States\n")
        code, out = self.check()
        self.assertEqual(code, 1)
        self.assertIn("countries", out)
        self.assertIn("no yml entry", out)

    def test_resource_declared_by_installed_package_counts_as_declared(self):
        # A project seed that overrides a package seed of the same name cannot
        # carry its own yml entry: dbt refuses two patches for one resource.
        _write(self.root, "seeds/pkg_exceptions.csv", "a,b\n1,2\n")
        _write(self.root, "dbt_packages/some_pkg/dbt_project.yml", "name: some_pkg\n")
        _write(self.root, "dbt_packages/some_pkg/seeds/seeds.yml",
               "version: 2\nseeds:\n  - name: pkg_exceptions\n    description: shipped by the package\n")
        code, out = self.check()
        self.assertEqual(code, 0, out)

    def test_version_override_of_a_base_column_is_not_a_duplicate(self):
        # A version may re-declare a base column (to add tests, say) without
        # repeating the description; that is an override, not a duplicate.
        _write(self.root, "models/marts/orders.yml",
               "version: 2\nmodels:\n  - name: orders\n    description: '{{ doc(\"orders\") }}'\n"
               "    latest_version: 1\n    columns:\n"
               "      - name: order_id\n        description: '{{ doc(\"order_id\") }}'\n"
               "      - name: amount\n        description: '{{ doc(\"amount\") }}'\n"
               "    versions:\n      - v: 1\n        columns:\n"
               "          - name: amount\n            tests: [not_null]\n")
        _write(self.root, "models/marts/orders_v1.sql", "select 1 as order_id, 2 as amount\n")
        code, out = self.check()
        self.assertEqual(code, 0, out)

    def test_snapshot_block_name_is_used_not_filename(self):
        # Legacy snapshot blocks name the resource inside the file.
        _write(self.root, "snapshots/legacy.sql",
               "{% snapshot orders_snapshot %}select 1{% endsnapshot %}\n")
        _write(self.root, "snapshots/legacy.yml",
               "version: 2\nsnapshots:\n  - name: orders_snapshot\n"
               "    description: '{{ doc(\"orders\") }}'\n")
        code, out = self.check()
        self.assertEqual(code, 0, out)


class ColumnsCommand(Fixture):
    UID = "model.%s.orders" % PROJECT

    def test_reports_live_columns_missing_from_yml(self):
        _catalog(self.root, {self.UID: ["order_id", "amount", "customer_id"]})
        code, out = self.columns()
        self.assertEqual(code, 0)  # not strict
        self.assertIn("customer_id", out)
        self.assertIn("missing", out)

    def test_reports_yml_columns_not_in_table_as_stale(self):
        _catalog(self.root, {self.UID: ["order_id"]})
        code, out = self.columns()
        self.assertIn("amount", out)
        self.assertIn("stale", out)

    def test_strict_fails_on_missing_or_stale(self):
        _catalog(self.root, {self.UID: ["order_id", "amount", "customer_id"]})
        code, _ = self.columns("--strict")
        self.assertEqual(code, 1)

    def test_strict_passes_when_yml_matches_table(self):
        _catalog(self.root, {self.UID: ["order_id", "amount"]})
        code, out = self.columns("--strict")
        self.assertEqual(code, 0, out)

    def test_first_level_nested_fields_are_informational(self):
        _catalog(self.root, {self.UID: ["order_id", "amount", "amount.units", "amount.units.raw"]})
        code, out = self.columns("--strict")
        self.assertEqual(code, 0, out)          # nested never fails strict
        self.assertIn("amount.units", out)      # first level is shown
        self.assertNotIn("amount.units.raw", out)  # deeper paths are not

    def test_nested_yml_entry_matching_a_live_path_is_not_stale(self):
        _write(self.root, "models/marts/orders.yml",
               self.orders_yml([("order_id", "'{{ doc(\"order_id\") }}'"),
                                ("amount", "'{{ doc(\"amount\") }}'"),
                                ("amount.units", "'{{ doc(\"amount\") }}'")]))
        _catalog(self.root, {self.UID: ["order_id", "amount", "amount.units"]})
        code, out = self.columns("--strict")
        self.assertEqual(code, 0, out)

    def test_column_names_compare_case_insensitively_and_ignore_backticks(self):
        _write(self.root, "models/marts/orders.yml",
               self.orders_yml([("Order_ID", "'{{ doc(\"order_id\") }}'"),
                                ("\"`amount`\"", "'{{ doc(\"amount\") }}'")]))
        _catalog(self.root, {self.UID: ["order_id", "amount"]})
        code, out = self.columns("--strict")
        self.assertEqual(code, 0, out)

    def test_resource_absent_from_catalog_is_skipped_not_failed(self):
        # A partial catalog (a PR build) only covers what was built.
        _catalog(self.root, {"model.%s.something_else" % PROJECT: ["x"]})
        _write(self.root, "models/marts/something_else.sql", "select 1 as x\n")
        _write(self.root, "models/marts/something_else.yml",
               "version: 2\nmodels:\n  - name: something_else\n    columns:\n"
               "      - name: x\n        description: '{{ doc(\"amount\") }}'\n")
        code, out = self.columns("--strict")
        self.assertEqual(code, 0, out)
        self.assertIn("not in catalog", out)

    def test_catalog_resource_with_no_yml_at_all_fails_strict(self):
        _write(self.root, "seeds/countries.csv", "code,name\n")
        _catalog(self.root, {self.UID: ["order_id", "amount"],
                             "seed.%s.countries" % PROJECT: ["code", "name"]})
        code, out = self.columns("--strict")
        self.assertEqual(code, 1)
        self.assertIn("countries", out)
        self.assertIn("no yml", out)

    def test_sources_are_keyed_by_source_and_table(self):
        _write(self.root, "models/sources/src_raw.yml",
               "version: 2\nsources:\n  - name: raw\n    tables:\n      - name: events\n"
               "        description: '{{ doc(\"orders\") }}'\n        columns:\n"
               "          - name: id\n            description: '{{ doc(\"order_id\") }}'\n")
        _catalog(self.root, {self.UID: ["order_id", "amount"]},
                 sources={"source.%s.raw.events" % PROJECT: ["id", "ts"]})
        code, out = self.columns("--strict")
        self.assertEqual(code, 1)
        self.assertIn("raw.events", out)
        self.assertIn("ts", out)

    def test_resource_types_filter_skips_sources(self):
        _write(self.root, "models/sources/src_raw.yml",
               "version: 2\nsources:\n  - name: raw\n    tables:\n      - name: events\n"
               "        columns:\n          - name: id\n            description: '{{ doc(\"order_id\") }}'\n")
        _catalog(self.root, {self.UID: ["order_id", "amount"]},
                 sources={"source.%s.raw.events" % PROJECT: ["id", "ts"]})
        code, out = self.columns("--strict", "--resource-types", "model,seed,snapshot")
        self.assertEqual(code, 0, out)

    def test_other_packages_are_ignored_by_default(self):
        _catalog(self.root, {self.UID: ["order_id", "amount"],
                             "model.other_pkg.thing": ["a", "b"]})
        code, out = self.columns("--strict")
        self.assertEqual(code, 0, out)
        self.assertNotIn("thing", out)

    def test_package_all_reads_installed_package_yml(self):
        # An installed package's yml lives under dbt_packages/<name>/.
        _write(self.root, "dbt_packages/other_pkg/dbt_project.yml", "name: other_pkg\n")
        _write(self.root, "dbt_packages/other_pkg/models/thing.sql", "select 1\n")
        _write(self.root, "dbt_packages/other_pkg/models/thing.yml",
               "version: 2\nmodels:\n  - name: thing\n    columns:\n"
               "      - name: a\n        description: 'x'\n")
        _catalog(self.root, {self.UID: ["order_id", "amount"],
                             "model.other_pkg.thing": ["a", "b"]})
        code, out = self.columns("--package", "all")
        self.assertIn("thing", out)
        self.assertIn("b", out)

    def test_stale_catalog_is_refused_with_max_age(self):
        _catalog(self.root, {self.UID: ["order_id", "amount"]}, hours_ago=30)
        code, out = self.columns("--strict", "--max-age", "24")
        self.assertEqual(code, 2)
        self.assertIn("older than", out)

    def test_fresh_catalog_passes_max_age(self):
        _catalog(self.root, {self.UID: ["order_id", "amount"]}, hours_ago=1)
        code, out = self.columns("--strict", "--max-age", "24")
        self.assertEqual(code, 0, out)

    def test_missing_catalog_file_is_a_usage_error(self):
        code, out = run(["--root", self.root, "columns", "--catalog",
                         os.path.join(self.root, "nope.json")])
        self.assertEqual(code, 2)
        self.assertIn("nope.json", out)

    def test_suggest_lists_reusable_blocks_for_missing_columns(self):
        _write(self.root, "models/marts/refunds.sql", "select 1 as refund_id, 2 as customer_id\n")
        _write(self.root, "models/marts/refunds.yml",
               "version: 2\nmodels:\n  - name: refunds\n    description: '{{ doc(\"orders\") }}'\n"
               "    columns:\n      - name: refund_id\n        description: '{{ doc(\"order_id\") }}'\n"
               "      - name: customer_id\n        description: '{{ doc(\"amount\") }}'\n")
        # orders is missing customer_id (a block of that name does not exist, but
        # refunds documents a column of that name) and shipped_at (nothing at all).
        _catalog(self.root, {self.UID: ["order_id", "amount", "customer_id", "shipped_at"]})
        _, out = self.columns("--suggest")
        self.assertIn('customer_id', out)
        self.assertIn('doc("amount")', out)          # used for a column of the same name elsewhere
        self.assertIn("shipped_at", out)
        self.assertIn("no existing block", out)

    def test_suggest_prefers_a_block_named_after_the_column(self):
        _write(self.root, "models/docs/marts/orders.md",
               "{% docs orders %}Orders.{% enddocs %}\n{% docs order_id %}The id.{% enddocs %}\n"
               "{% docs amount %}The amount.{% enddocs %}\n{% docs customer_id %}The customer.{% enddocs %}\n")
        _catalog(self.root, {self.UID: ["order_id", "amount", "customer_id"]})
        _, out = self.columns("--suggest")
        self.assertIn('doc("customer_id")', out)
        self.assertIn("The customer.", out)

    def test_summary_line_counts(self):
        _catalog(self.root, {self.UID: ["order_id", "customer_id", "meta.k"]})
        _, out = self.columns()
        self.assertRegex(out, r"missing[^\n]*1")
        self.assertRegex(out, r"stale[^\n]*1")


if __name__ == "__main__":
    unittest.main(verbosity=1)
