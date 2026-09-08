#!/usr/bin/env python
"""Lint and inspect dbt doc-block usage without needing a warehouse connection.

`doc()` resolves by block name, not by file path, so the rendered description for
every model and column can be computed statically from the yml + md files alone.
That makes a before/after comparison cheap and credential-free: see the `snapshot`
and `diff` commands. `validate-manifest` proves the resolver agrees with dbt.

Commands:
    snapshot          write the resolved description map to a JSON file
    diff A B          compare two snapshot files
    validate-manifest check the resolver against target/manifest.json
    report            fanout, orphans, divergences, suspicious refs
    check             enforce the lint rules (exit 1 on violation)
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
MODEL_PATHS = ("models", "snapshots", "seeds", "analyses", "tests", "macros")

# The single home for definitions shared across unrelated tables. One obvious
# place beats two plausible ones: before this was enforced, shared columns were
# split between universal.md and sources/state_tables.md with no rule saying
# which, and new columns ended up in neither.
UNIVERSAL = os.path.join("models", "docs", "universal.md")

# A block is "shared" when unrelated table families use it, not merely when
# several files do. A column flowing src -> stg -> mart shows up in three files
# but is one family, and belongs in that source's own mirror file.
SHARED_FAMILY_THRESHOLD = 4

ALLOWLIST = os.path.join("scripts", "docs_allowlist.txt")
REF_IGNORE = os.path.join("scripts", "docs_ref_ignore.txt")
BLOCK_EXCEPTIONS = os.path.join("scripts", "docs_block_exceptions.txt")

DOCS_BLOCK_RE = re.compile(
    r"\{%-?\s*docs\s+([A-Za-z0-9_]+)\s*-?%\}(.*?)\{%-?\s*enddocs\s*-?%\}", re.DOTALL
)
DOC_CALL_RE = re.compile(r"""\{\{-?\s*doc\(\s*['"]([A-Za-z0-9_]+)['"]\s*\)\s*-?\}\}""")

# A description that is exactly one doc() call and nothing else. Anything more
# (prose plus a doc call, two doc calls) is left alone: it is not a plain reference.
PURE_DOC_RE = re.compile(
    r"""^\s*\{\{-?\s*doc\(\s*['"]([A-Za-z0-9_]+)['"]\s*\)\s*-?\}\}\s*$"""
)


# --------------------------------------------------------------------------- #
# collection
# --------------------------------------------------------------------------- #


def walk_files(root, suffixes):
    for base in MODEL_PATHS:
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


def _entries(doc):
    """Yield (kind, resource_name, description, columns, ...) from one parsed yml."""
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
    """Every declared description, with enough context to lint and to resolve it.

    Returns a list of dicts: kind, resource, column (None for resource level),
    file, raw description, and the doc block name when the description is a
    single plain doc() call.
    """
    rows = []
    parse_errors = []
    for path, rel in walk_files(root, (".yml", ".yaml")):
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
    pure = PURE_DOC_RE.match(raw)
    return {
        "kind": kind,
        "resource": resource,
        "column": column,
        "file": rel,
        "raw": raw,
        "ref": pure.group(1) if pure else None,
        "refs": DOC_CALL_RE.findall(raw),
    }


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
    """Collapse one table's src/stg/int/mart variants to a single family name."""
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


def cmd_snapshot(args):
    blocks, _dupes = load_blocks(args.root)
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
    package = args.package
    truth = {}
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
            truth["%s:%s:" % (kind, name)] = (node.get("description") or "").strip()
            for column, meta in (node.get("columns") or {}).items():
                truth["%s:%s:%s" % (kind, name, column)] = (
                    meta.get("description") or ""
                ).strip()

    blocks, _dupes = load_blocks(args.root)
    rows, _errors = load_properties(args.root)
    resolved, unresolved = resolve(rows, blocks)

    common = set(truth) & set(resolved)
    mismatched = sorted(k for k in common if truth[k] != resolved[k])
    only_manifest = sorted(k for k in set(truth) - set(resolved) if truth[k])
    only_static = sorted(set(resolved) - set(truth))

    print("manifest descriptions: %d" % len(truth))
    print("statically resolved:   %d" % len(resolved))
    print("compared in common:    %d" % len(common))
    print("MISMATCHED:            %d" % len(mismatched))
    print("in manifest only (non-empty): %d" % len(only_manifest))
    print("in yml only (not built/selected): %d" % len(only_static))
    for key in mismatched[: args.show]:
        print("\n--- %s" % key)
        print("  dbt   : %r" % truth[key][:200])
        print("  static: %r" % resolved[key][:200])
    for key in only_manifest[: args.show]:
        print("  manifest-only: %s" % key)
    if unresolved:
        print("\nunresolved doc() refs: %d" % len(unresolved))
    return 1 if mismatched else 0


def cmd_report(args):
    blocks, dupes = load_blocks(args.root)
    rows, errors = load_properties(args.root)
    resolved, unresolved = resolve(rows, blocks)

    usage = block_usage(rows)
    users = {n: fs for n, (fs, _fam) in usage.items()}
    families = {n: fam for n, (_fs, fam) in usage.items()}

    fanout = Counter(len(users.get(name, ())) for name in blocks)
    orphans = sorted(name for name in blocks if not users.get(name))
    single = sorted(n for n in blocks if len(users.get(n, ())) == 1)
    shared = sorted(
        n for n in blocks if len(families.get(n, ())) >= SHARED_FAMILY_THRESHOLD
    )

    print("=== blocks ===")
    print("defined: %d   orphan: %d   single-use: %d   cross-family shared (>=%d families): %d"
          % (len(blocks), len(orphans), len(single), SHARED_FAMILY_THRESHOLD, len(shared)))
    print("file fanout distribution: %s"
          % ", ".join("%d->%d" % (k, fanout[k]) for k in sorted(fanout)))
    famdist = Counter(len(families.get(n, ())) for n in blocks)
    print("family fanout distribution: %s"
          % ", ".join("%d->%d" % (k, famdist[k]) for k in sorted(famdist)))
    if dupes:
        print("DUPLICATE block names: %s" % dupes)
    if errors:
        print("yml parse errors: %s" % errors)

    literals = [r for r in rows if not r["refs"] and r["raw"].strip()]
    print("\n=== descriptions ===")
    print("total: %d   pure doc() ref: %d   inline literal: %d"
          % (len(rows), sum(1 for r in rows if r["ref"]), len(literals)))
    by_file = Counter(r["file"] for r in literals)
    print("files with inline literals: %d" % len(by_file))
    for path, count in by_file.most_common(args.show):
        print("   %4d  %s" % (count, path))

    print("\n=== misplaced blocks (family-fanout rule) ===")
    wrong_shared = [n for n in shared if blocks[n]["file"] != UNIVERSAL]
    stranded = [
        n for n in blocks
        if blocks[n]["file"] == UNIVERSAL and len(families.get(n, ())) < 2
    ]
    print("used by >=%d families but not in %s: %d"
          % (SHARED_FAMILY_THRESHOLD, UNIVERSAL, len(wrong_shared)))
    for name in wrong_shared:
        print("   %2d families  %-32s <- %s"
              % (len(families[name]), name, blocks[name]["file"]))
    print("in %s but used by <2 families: %d" % (UNIVERSAL, len(stranded)))
    for name in stranded:
        print("   %2d families  %s" % (len(families.get(name, ())), name))

    print("\n=== divergent column definitions ===")
    per_column = defaultdict(set)
    for row in rows:
        if not row["column"]:
            continue
        text = resolved.get(key_of(row))
        if text:
            per_column[row["column"]].add(text)
    divergent = {c: v for c, v in per_column.items() if len(v) > 1}
    print("column names resolving to more than one text: %d" % len(divergent))

    print("\n=== suspicious refs (possible wrong-block copy-paste) ===")
    for row, ref, score in suspicious_refs(rows, blocks, args.threshold):
        print("   %.2f  %s -> doc('%s')   %s" % (score, row["column"], ref, row["file"]))
    return 0


def suspicious_refs(rows, blocks, threshold):
    """A column referencing a different block when one named after it exists.

    A close-but-not-equal name is the signature of a copy-paste error between
    paired columns (asset_a / asset_b, read_bytes / write_bytes), which is why
    high similarity is treated as suspicious rather than safe.
    """
    hits = []
    for row in rows:
        name = row["column"]
        ref = row["ref"]
        if not name or not ref or ref == name or name not in blocks:
            continue
        score = difflib.SequenceMatcher(None, name, ref).ratio()
        if score >= threshold:
            hits.append((row, ref, score))
    hits.sort(key=lambda h: -h[2])
    return hits


def load_list(root, relpath):
    path = os.path.join(root, relpath)
    if not os.path.isfile(path):
        return set()
    entries = set()
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.split("#", 1)[0].strip()
            if line:
                entries.add(line)
    return entries


def cmd_check(args):
    blocks, dupes = load_blocks(args.root)
    rows, errors = load_properties(args.root)
    resolved, unresolved = resolve(rows, blocks)
    allowlist = load_list(args.root, ALLOWLIST)
    ref_ignore = load_list(args.root, REF_IGNORE)
    block_exceptions = load_list(args.root, BLOCK_EXCEPTIONS)
    usage = block_usage(rows)
    only = set(args.files or [])
    problems = []

    def flag(rule, message):
        problems.append((rule, message))

    for rel, message in errors:
        flag("R0", "%s: cannot parse yml: %s" % (rel, message))
    for name, files in sorted(dupes.items()):
        flag("R0", "doc block '%s' defined in %d files: %s" % (name, len(files), files))

    for row in unresolved:
        missing = [n for n in row["refs"] if n not in blocks]
        flag("R2", "%s: %s references undefined block(s) %s"
             % (row["file"], row["column"] or row["resource"], missing))

    # R1: inline literals outside the allowlist.
    for row in rows:
        if row["refs"] or not row["raw"].strip():
            continue
        if row["file"] in allowlist:
            continue
        if only and row["file"] not in only:
            continue
        target = row["column"] or "(%s level)" % row["kind"]
        flag("R1", "%s: %s has an inline description; define a doc block instead"
             % (row["file"], target))

    # R6: stale allowlist entries, so the ratchet cannot silently stall.
    files_with_literals = {
        r["file"] for r in rows if not r["refs"] and r["raw"].strip()
    }
    for rel in sorted(allowlist - files_with_literals):
        flag("R6", "%s is on the allowlist but has no inline descriptions; remove the entry"
             % rel)

    # R3: shared definitions belong in one place, so there is one obvious answer
    # to "where does a new shared column go".
    for name, meta in sorted(blocks.items()):
        count = len(usage.get(name, ((), ()))[1])
        if count < SHARED_FAMILY_THRESHOLD or meta["file"] == UNIVERSAL:
            continue
        if name in block_exceptions:
            continue
        flag("R3", "doc block '%s' is used by %d table families but is defined in "
                   "%s; move it to %s, or park it in %s with a reason"
             % (name, count, meta["file"], UNIVERSAL, BLOCK_EXCEPTIONS))

    # R8: a parked exception that no longer applies.
    for name in sorted(block_exceptions):
        if name not in blocks:
            flag("R8", "'%s' is listed in %s but no such doc block exists"
                 % (name, BLOCK_EXCEPTIONS))
            continue
        count = len(usage.get(name, ((), ()))[1])
        if count < SHARED_FAMILY_THRESHOLD or blocks[name]["file"] == UNIVERSAL:
            flag("R8", "'%s' no longer trips R3; remove it from %s"
                 % (name, BLOCK_EXCEPTIONS))

    # R5: a ref that looks like a wrong-block copy-paste. Close-but-unequal names
    # are how paired columns get crossed, so this warns rather than trusting them.
    for row, ref, score in suspicious_refs(rows, blocks, args.threshold):
        if only and row["file"] not in only:
            continue
        token = "%s:%s:%s" % (row["file"], row["column"], ref)
        if token in ref_ignore:
            continue
        flag("R5", "%s: %s references doc('%s') though a block named '%s' exists "
                   "(name similarity %.2f). If deliberate, add this line to %s:\n"
                   "        %s"
             % (row["file"], row["column"], ref, row["column"], score, REF_IGNORE, token))

    # R7: an ignore entry that no longer matches, so the file cannot rot.
    live = {
        "%s:%s:%s" % (r["file"], r["column"], ref)
        for r, ref, _s in suspicious_refs(rows, blocks, args.threshold)
    }
    for token in sorted(ref_ignore - live):
        flag("R7", "%s no longer matches any suspicious ref; remove it from %s"
             % (token, REF_IGNORE))

    for rule, message in problems:
        print("%s  %s" % (rule, message))
    if problems:
        print("\n%d problem(s). Rules: R0 structural, R1 inline literal, R2 undefined "
              "block, R3 misplaced shared block, R5 suspicious ref, R6 stale allowlist, "
              "R7 stale ref-ignore, R8 stale block exception." % len(problems))
        return 1
    print("docs_lint: clean (%d descriptions, %d blocks)" % (len(rows), len(blocks)))
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", default=REPO_ROOT, help="repo root (default: this repo)")
    sub = parser.add_subparsers(dest="command", required=True)

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
    p.add_argument("--package", default="stellar_dbt_public")
    p.add_argument("--show", type=int, default=10)
    p.set_defaults(func=cmd_validate_manifest)

    p = sub.add_parser("report", help="fanout, orphans, divergences, suspicious refs")
    p.add_argument("--show", type=int, default=20)
    p.add_argument("--threshold", type=float, default=0.85)
    p.set_defaults(func=cmd_report)

    p = sub.add_parser("check", help="enforce the lint rules")
    p.add_argument("files", nargs="*", help="limit file-scoped rules to these paths")
    p.add_argument("--threshold", type=float, default=0.85)
    p.set_defaults(func=cmd_check)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
