#!/usr/bin/env python
"""Keep every model and column description in a doc block, not inline in yml.

One rule, no exceptions, no tunable thresholds: a `description:` on a model,
source table, seed, snapshot, analysis or any of their columns must be exactly one
`{{ doc("name") }}` reference to a block that exists. The definition itself lives
in a `models/docs/**/*.md` doc block.

Macro and argument descriptions are deliberately out of scope. They document one
macro's signature, so there is nothing to factor out, and moving them away from
the macro would only make them harder to keep true. Doc blocks defined under
`macros/` still resolve, because dbt looks for them there.

This file is identical in stellar-dbt and stellar-dbt-public and is meant to stay
that way: the project name comes from `dbt_project.yml` rather than a constant, so
copy it across verbatim rather than porting changes by hand.

The rule applies everywhere except the paths listed in
`scripts/docs_lint_todo.txt`, which are domains whose inline descriptions predate
the rule and are being converted a domain at a time. That list only ever shrinks:
a new file anywhere is enforced from the start, and an entry with no remaining
inline descriptions is itself a failure, so a converted domain cannot be left
listed. When the file is empty, delete it and the two lines that read it.

The other commands are inspection tools rather than gates. `doc()` resolves by
block name and not by file path, so every rendered description can be computed
from the yml + md files alone, with no warehouse connection. That makes a
before/after comparison cheap: `snapshot` twice and `diff` proves whether a
change altered any published text. `validate-manifest` shows the resolver
agrees with dbt itself.

This project also references doc blocks defined in the `stellar_dbt_public`
package, so resolution reads `dbt_packages/` as well as this repo. Those blocks
resolve but are never linted here; they belong to the other repo. Run
`dbt deps` if resolution reports blocks it cannot find.

Commands:
    check             enforce the rule (exit 1 on violation)
    snapshot          write the resolved description map to a JSON file
    diff A B          compare two snapshot files
    validate-manifest check the resolver against target/manifest.json
    report            block fanout, orphans, duplicate column keys, and columns
                      documented inconsistently
"""

from __future__ import annotations

import argparse
import difflib
import json
import os
import re
import sys
from collections import Counter, defaultdict

import yaml

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Everywhere dbt looks for a doc block, so the resolver sees every block dbt does.
DOC_SEARCH_PATHS = ("models", "snapshots", "seeds", "analyses", "tests", "macros")
# Only the paths whose properties yml the rule governs. `macros` and `tests` are
# excluded on purpose; see the module docstring.
PROPERTY_PATHS = ("models", "snapshots", "seeds", "analyses")
PACKAGES_DIR = "dbt_packages"
TODO_FILE = os.path.join("scripts", "docs_lint_todo.txt")
# Faults a not-yet-converted path is allowed to still have. Everything else in
# `describe_fault` fails everywhere.
DEFERRABLE_FAULTS = frozenset(("inline", "mixed"))

DOCS_BLOCK_RE = re.compile(
    r"\{%-?\s*docs\s+([A-Za-z0-9_]+)\s*-?%\}(.*?)\{%-?\s*enddocs\s*-?%\}", re.DOTALL
)
DOC_CALL_RE = re.compile(r"""\{\{-?\s*doc\(\s*['"]([A-Za-z0-9_]+)['"]\s*\)\s*-?\}\}""")


# --------------------------------------------------------------------------- #
# collection
# --------------------------------------------------------------------------- #


def walk_files(root, suffixes, bases=DOC_SEARCH_PATHS):
    for base in bases:
        top = os.path.join(root, base)
        if not os.path.isdir(top):
            continue
        for dirpath, _dirnames, filenames in os.walk(top):
            for name in sorted(filenames):
                if name.endswith(suffixes):
                    path = os.path.join(dirpath, name)
                    yield path, os.path.relpath(path, root)


def load_blocks(root):
    """name -> {"text": body, "file": relpath}. Also returns duplicate definitions."""
    blocks = {}
    duplicates = defaultdict(list)
    for path, rel in walk_files(root, (".md",)):
        with open(path, encoding="utf-8") as handle:
            content = handle.read()
        for match in DOCS_BLOCK_RE.finditer(content):
            name = match.group(1)
            duplicates[name].append(rel)
            if name not in blocks:
                blocks[name] = {"text": match.group(2).strip(), "file": rel}
    return blocks, {k: v for k, v in duplicates.items() if len(v) > 1}


def project_name(root):
    """This dbt project's package name, so no per-repo constant is needed."""
    path = os.path.join(root, "dbt_project.yml")
    with open(path, encoding="utf-8") as handle:
        return (yaml.safe_load(handle) or {}).get("name")


def load_todo(root):
    """Path prefixes exempt from the rule, from `scripts/docs_lint_todo.txt`."""
    path = os.path.join(root, TODO_FILE)
    if not os.path.isfile(path):
        return []
    prefixes = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.split("#", 1)[0].strip()
            if line:
                prefixes.append(line)
    return prefixes


def load_package_blocks(root):
    """Doc blocks defined by installed packages, for resolution only.

    dbt resolves a `doc()` in the local package first and falls back to installed
    packages, so a reference to a `stellar_dbt_public` block is legitimate here.
    Nothing in `check` applies to these; a duplicate name between the two repos is
    also legitimate, since the local definition wins.
    """
    blocks = {}
    top = os.path.join(root, PACKAGES_DIR)
    if not os.path.isdir(top):
        return blocks
    for dirpath, _dirnames, filenames in os.walk(top):
        for name in sorted(filenames):
            if not name.endswith(".md"):
                continue
            path = os.path.join(dirpath, name)
            with open(path, encoding="utf-8", errors="replace") as handle:
                content = handle.read()
            for match in DOCS_BLOCK_RE.finditer(content):
                blocks.setdefault(
                    match.group(1),
                    {"text": match.group(2).strip(), "file": os.path.relpath(path, root)},
                )
    return blocks


def all_blocks(root):
    """Local blocks plus package blocks, with local winning, as dbt resolves them."""
    local, dupes = load_blocks(root)
    merged = dict(load_package_blocks(root))
    merged.update(local)
    return local, merged, dupes


def _entries(doc):
    """Yield (kind, resource_name, node) for every documentable resource in a yml."""
    if not isinstance(doc, dict):
        return
    for key, kind in (
        ("models", "model"),
        ("seeds", "seed"),
        ("snapshots", "snapshot"),
        ("analyses", "analysis"),
    ):
        for item in doc.get(key) or []:
            if isinstance(item, dict) and item.get("name"):
                yield kind, item["name"], item
    for source in doc.get("sources") or []:
        if not isinstance(source, dict):
            continue
        for table in source.get("tables") or []:
            if isinstance(table, dict) and table.get("name"):
                yield "source", "%s.%s" % (source.get("name"), table["name"]), table


def load_properties(root):
    """Every declared description, with enough context to lint and to resolve it."""
    rows = []
    parse_errors = []
    for path, rel in walk_files(root, (".yml", ".yaml"), PROPERTY_PATHS):
        with open(path, encoding="utf-8") as handle:
            try:
                doc = yaml.safe_load(handle)
            except yaml.YAMLError as exc:  # pragma: no cover - malformed yml
                parse_errors.append((rel, str(exc).splitlines()[0]))
                continue
        for kind, resource, node in _entries(doc):
            if "description" in node:
                rows.append(_row(kind, resource, None, rel, node["description"]))
            for column in node.get("columns") or []:
                if isinstance(column, dict) and column.get("name") and "description" in column:
                    rows.append(
                        _row(kind, resource, column["name"], rel, column["description"])
                    )
    return rows, parse_errors


def _row(kind, resource, column, rel, description):
    raw = "" if description is None else str(description)
    return {
        "kind": kind,
        "resource": resource,
        "column": column,
        "file": rel,
        "raw": raw,
        "refs": DOC_CALL_RE.findall(raw),
    }


def describe_fault(row, blocks):
    """(kind, message) when a description breaks the rule, else None.

    The rule is that the whole value is one `doc()` call naming a block that
    exists. Anything else either publishes inline text or breaks `dbt parse`:
    an empty value documents nothing, `see {{ doc("x") }}` keeps prose in the
    yml, and a typo'd name is a parse error waiting for the next dbt run.
    """
    raw = row["raw"]
    refs = row["refs"]
    if not refs:
        if not raw.strip():
            return ("empty", "has an empty description. Give it a doc block "
                             "reference or remove the key.")
        return ("inline", "has an inline description. Move the text into a doc "
                          "block under models/docs/ and reference it with "
                          "'{{ doc(\"name\") }}'.")
    missing = [name for name in refs if name not in blocks]
    if missing:
        return ("undefined", "references doc block(s) %s, which are not defined "
                             "anywhere; dbt parse will fail."
                             % ", ".join("'%s'" % m for m in missing))
    if len(refs) > 1:
        return ("multiple", "combines %d doc() calls. Reference one block, and "
                            "if the text really is two things, write a block "
                            "that says both." % len(refs))
    leftover = DOC_CALL_RE.sub("", raw).strip()
    if leftover:
        return ("mixed", "wraps its doc() call in inline text (%r). The whole "
                         "description must be the reference." % leftover[:60])
    return None


def resolve(rows, blocks):
    """Render every description the way dbt would, by substituting doc() calls."""
    resolved = {}
    unresolved = []
    for row in rows:
        if any(name not in blocks for name in row["refs"]):
            unresolved.append(row)
            continue
        text = DOC_CALL_RE.sub(lambda m: blocks[m.group(1)]["text"], row["raw"])
        resolved[key_of(row)] = text.strip()
    return resolved, unresolved


def key_of(row):
    return "%s:%s:%s" % (row["kind"], row["resource"], row["column"] or "")


FAMILY_SUBS = (
    (re.compile(r"^(src_|stg_|int_|enriched_)"), ""),
    (re.compile(r"_(xlm|current|snapshot|raw)$"), ""),
    (re.compile(r"_(day|week|month|year|daily|hourly)(_agg)?$"), ""),
    (re.compile(r"_agg$"), ""),
    (re.compile(r"^history_"), ""),
)


def family(rel):
    """Collapse one table's src/stg/int/mart variants to a single family name.

    Used only by `report`. A column flowing src -> stg -> mart shows up in several
    files but is one table's column, so counting files overstates how widely a
    definition is really shared.
    """
    name = os.path.basename(rel).rsplit(".", 1)[0]
    for pattern, replacement in FAMILY_SUBS:
        name = pattern.sub(replacement, name)
    return name


def block_usage(rows):
    """block name -> (referencing files, distinct table families)."""
    files = defaultdict(set)
    for row in rows:
        for name in row["refs"]:
            files[name].add(row["file"])
    return {n: (fs, {family(f) for f in fs}) for n, fs in files.items()}


# --------------------------------------------------------------------------- #
# commands
# --------------------------------------------------------------------------- #


def cmd_check(args):
    """The gate: every description must be a doc() reference."""
    # `dupes` is local-only: a name defined in both this repo and an installed
    # package is legitimate (the local one wins), but twice in this repo is not.
    # `resolvable` is the merged set, which is what a doc() call can reach.
    local, resolvable, dupes = all_blocks(args.root)
    rows, errors = load_properties(args.root)
    todo = load_todo(args.root)
    only = set(args.files or [])
    problems = []

    # A yml that will not parse gets no rule applied at all, so treat it as a
    # failure rather than silently skipping the file.
    for rel, message in errors:
        problems.append("%s: cannot parse yml: %s" % (rel, message))
    for name, files in sorted(dupes.items()):
        problems.append(
            "doc block '%s' is defined in %d files (%s); dbt cannot resolve a "
            "duplicate name" % (name, len(files), ", ".join(files))
        )

    deferred = defaultdict(int)
    for row in rows:
        fault = describe_fault(row, resolvable)
        if not fault:
            continue
        # Inline text is deferrable, whole or partial, because an unconverted
        # domain is full of it. A reference that cannot resolve, or an empty
        # description, is a defect in code that already adopted the rule, so it
        # fails even inside a todo path.
        exempt = next((p for p in todo if row["file"].startswith(p)), None)
        if exempt and fault[0] in DEFERRABLE_FAULTS:
            deferred[exempt] += 1
            continue
        if only and row["file"] not in only:
            continue
        target = row["column"] or "(%s level)" % row["kind"]
        problems.append("%s: %s %s" % (row["file"], target, fault[1]))

    # An entry that no longer defers anything is a converted domain still listed,
    # so the list cannot quietly outlive the migration.
    for prefix in todo:
        if not os.path.exists(os.path.join(args.root, prefix)):
            problems.append(
                "%s lists '%s', which does not exist" % (TODO_FILE, prefix)
            )
        elif not deferred.get(prefix):
            problems.append(
                "%s lists '%s', which has no inline descriptions left; delete the "
                "line" % (TODO_FILE, prefix)
            )

    for message in problems:
        print(message)
    if problems:
        print("\n%d problem(s)." % len(problems))
        return 1
    print("docs_lint: clean (%d descriptions, %d blocks)" % (len(rows), len(local)))
    if deferred:
        print("\nnot yet converted (%s):" % TODO_FILE)
        for prefix in sorted(deferred, key=lambda p: -deferred[p]):
            print("   %4d inline  %s" % (deferred[prefix], prefix))
        print("   %4d total" % sum(deferred.values()))
    return 0


def cmd_snapshot(args):
    _local, blocks, _dupes = all_blocks(args.root)
    rows, _errors = load_properties(args.root)
    resolved, unresolved = resolve(rows, blocks)
    with open(args.out, "w", encoding="utf-8") as handle:
        json.dump(resolved, handle, indent=1, sort_keys=True)
        handle.write("\n")
    print("wrote %d resolved descriptions to %s" % (len(resolved), args.out))
    if unresolved:
        print("WARNING: %d descriptions reference an undefined block" % len(unresolved))
    return 0


def cmd_diff(args):
    before = json.load(open(args.before, encoding="utf-8"))
    after = json.load(open(args.after, encoding="utf-8"))
    added = sorted(set(after) - set(before))
    removed = sorted(set(before) - set(after))
    changed = sorted(k for k in set(before) & set(after) if before[k] != after[k])
    for label, keys in (("removed", removed), ("added", added), ("changed", changed)):
        for key in keys:
            print("%s  %s" % (label.upper().ljust(7), key))
            if label == "changed":
                for line in difflib.unified_diff(
                    before[key].splitlines(), after[key].splitlines(), lineterm="", n=0
                ):
                    if line.startswith(("---", "+++")):
                        continue
                    print("         %s" % line)
    total = len(added) + len(removed) + len(changed)
    print(
        "\n%d differences (%d added, %d removed, %d changed)"
        % (total, len(added), len(removed), len(changed))
    )
    return 1 if total and args.strict else 0


def cmd_validate_manifest(args):
    """Compare the static resolver against dbt's own rendered descriptions."""
    manifest = json.load(open(args.manifest, encoding="utf-8"))
    package = args.package or project_name(args.root)
    truth = {}
    foreign = set()  # keys whose description text lives in an installed package
    for section in ("nodes", "sources"):
        for node in manifest.get(section, {}).values():
            if node.get("package_name") != package:
                continue
            kind = node.get("resource_type")
            if kind == "test":
                continue
            name = node["name"]
            if kind == "source":
                name = "%s.%s" % (node.get("source_name"), name)
            # A patch_path of "<package>://path" says which project's yml supplied
            # the description. Another project's yml is not on disk here, so the
            # resolver cannot see it and its absence is not a coverage gap.
            patch = node.get("patch_path") or ""
            owner = patch.split("://", 1)[0] if "://" in patch else package
            keys = ["%s:%s:" % (kind, name)]
            truth[keys[0]] = (node.get("description") or "").strip()
            for column, meta in (node.get("columns") or {}).items():
                key = "%s:%s:%s" % (kind, name, column)
                truth[key] = (meta.get("description") or "").strip()
                keys.append(key)
            if owner != package:
                foreign.update(keys)

    _local, blocks, _dupes = all_blocks(args.root)
    rows, _errors = load_properties(args.root)
    resolved, unresolved = resolve(rows, blocks)

    common = set(truth) & set(resolved)
    mismatched = sorted(k for k in common if truth[k] != resolved[k])
    missed = set(k for k in set(truth) - set(resolved) if truth[k])
    # Two very different reasons a manifest description is not resolved here.
    package_owned = sorted(missed & foreign)
    unexplained = sorted(missed - foreign)
    only_static = sorted(set(resolved) - set(truth))

    print("manifest descriptions: %d" % len(truth))
    print("statically resolved:   %d" % len(resolved))
    print("compared in common:    %d" % len(common))
    print("MISMATCHED:            %d" % len(mismatched))
    print("NOT COMPARED (patched by an installed package): %d" % len(package_owned))
    print("NOT COMPARED (unexplained, a real gap):         %d" % len(unexplained))
    print("in yml only (not built/selected): %d" % len(only_static))
    for key in mismatched[: args.show]:
        print("\n--- %s" % key)
        print("  dbt   : %r" % truth[key][:200])
        print("  static: %r" % resolved[key][:200])
    for key in unexplained[: args.show]:
        print("NOT COMPARED: %s -> %r" % (key, truth[key][:120]))
    if unresolved:
        print("\nunresolved doc() refs: %d" % len(unresolved))
        for row in unresolved[: args.show]:
            print("   %s: %s" % (row["file"], row["column"] or "(model level)"))
    # Only MISMATCHED: 0 plus nothing unexplained and nothing unresolved lets a
    # caller treat this as proof the resolver stands in for dbt.
    return 1 if mismatched or unexplained or unresolved else 0


def cmd_report(args):
    """Read-only diagnostics. Nothing here fails a build."""
    blocks, merged, dupes = all_blocks(args.root)
    rows, errors = load_properties(args.root)
    resolved, unresolved = resolve(rows, merged)
    usage = block_usage(rows)
    users = {n: fs for n, (fs, _fam) in usage.items()}
    families = {n: fam for n, (_fs, fam) in usage.items()}

    orphans = sorted(name for name in blocks if not users.get(name))
    print("=== blocks ===")
    print("defined: %d   orphan (referenced by nothing): %d" % (len(blocks), len(orphans)))
    print("file fanout:   %s" % _dist(len(users.get(n, ())) for n in blocks))
    print("family fanout: %s" % _dist(len(families.get(n, ())) for n in blocks))
    if orphans:
        print("orphans: %s" % ", ".join(orphans))
    if dupes:
        print("DUPLICATE block names: %s" % dupes)
    if errors:
        print("yml parse errors: %s" % errors)
    if unresolved:
        print("descriptions referencing an undefined block: %d" % len(unresolved))

    print("\n=== most widely shared blocks ===")
    ranked = sorted(blocks, key=lambda n: -len(families.get(n, ())))
    for name in ranked[: args.show]:
        print("   %2d families / %2d files  %-34s <- %s"
              % (len(families.get(name, ())), len(users.get(name, ())), name,
                 blocks[name]["file"]))

    print("\n=== columns declared twice under one resource ===")
    print("The later entry wins, so the earlier description is dropped and one")
    print("column ends up publishing another column's text. dbt does not warn.")
    dup_cols = []
    for path, rel in walk_files(args.root, (".yml", ".yaml"), PROPERTY_PATHS):
        try:
            doc = yaml.safe_load(open(path, encoding="utf-8"))
        except yaml.YAMLError:
            continue
        for kind, resource, node in _entries(doc):
            names = [c["name"] for c in (node.get("columns") or [])
                     if isinstance(c, dict) and c.get("name")]
            for name, count in sorted(Counter(names).items()):
                if count > 1:
                    dup_cols.append((rel, resource, name, count))
    for rel, resource, name, count in dup_cols:
        print("   %-62s %s.%s  x%d" % (rel, resource, name, count))
    print("total: %d" % len(dup_cols))

    print("\n=== columns documented inconsistently ===")
    print("Same column name, more than one description. Divergence across unrelated")
    print("tables is often correct; divergence inside one table family rarely is.")
    per_column = defaultdict(list)
    for row in rows:
        if row["column"]:
            per_column[row["column"]].append(row)
    intra, cross = [], []
    for column, group in per_column.items():
        texts = {resolved.get(key_of(r), "") for r in group}
        if len(texts) < 2:
            continue
        per_family = defaultdict(set)
        for row in group:
            per_family[family(row["file"])].add(resolved.get(key_of(row), ""))
        hits = sorted(f for f, t in per_family.items() if len(t) > 1)
        (intra if hits else cross).append((column, len(texts), hits, group))
    print("within one table family: %d      across families only: %d"
          % (len(intra), len(cross)))
    for column, count, hits, group in sorted(intra, key=lambda x: -x[1]):
        print("\n   %s  (%d descriptions; families: %s)"
              % (column, count, ", ".join(hits)))
        for row in sorted(group, key=lambda r: r["file"]):
            if family(row["file"]) not in hits:
                continue
            ref = row["refs"][0] if row["refs"] else "INLINE"
            print("      %-40s doc(%s)" % (row["file"], ref))
    return 0


def _dist(values):
    counter = Counter(values)
    return ", ".join("%d->%d" % (k, counter[k]) for k in sorted(counter))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", default=REPO_ROOT, help="repo root (default: this repo)")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("check", help="enforce the rule")
    p.add_argument("files", nargs="*", help="limit the check to these paths")
    p.set_defaults(func=cmd_check)

    p = sub.add_parser("snapshot", help="write resolved descriptions to JSON")
    p.add_argument("--out", default="docs_snapshot.json")
    p.set_defaults(func=cmd_snapshot)

    p = sub.add_parser("diff", help="compare two snapshots")
    p.add_argument("before")
    p.add_argument("after")
    p.add_argument("--strict", action="store_true", help="exit 1 when anything differs")
    p.set_defaults(func=cmd_diff)

    p = sub.add_parser("validate-manifest", help="check the resolver against dbt")
    p.add_argument("--manifest", default="target/manifest.json")
    p.add_argument("--package", default=None,
                   help="dbt package name (default: read from dbt_project.yml)")
    p.add_argument("--show", type=int, default=10)
    p.set_defaults(func=cmd_validate_manifest)

    p = sub.add_parser("report", help="fanout, orphans, inconsistent columns")
    p.add_argument("--show", type=int, default=15)
    p.set_defaults(func=cmd_report)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
