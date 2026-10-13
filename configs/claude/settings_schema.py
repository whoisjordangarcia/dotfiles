#!/usr/bin/env python3
"""Check Claude Code settings files against the current docs, and regenerate
settings.schema.json for editors.

json.schemastore.org/claude-code-settings.json lags the CLI, marks deprecations
only in prose, and accepts any key. The settings reference at code.claude.com
is current, so this reads it on every run and checks each file for:

  * deprecated or removed keys
  * keys the docs don't list (typos, keys that never existed)
  * keys scoped to ~/.claude.json or managed settings, which settings.json ignores
  * values whose type or enum the docs rule out

An invalid value makes Claude Code offer to drop the whole settings file, and
these files carry the touchid-gate hooks, so a failure here is worth fixing.

Usage:
    ./settings_schema.py                  # check settings.{work,personal}.json, rewrite the schema
    ./settings_schema.py FILE...          # check these files instead
    ./settings_schema.py --ref R --base B --out O FILE...   # offline inputs (the tests)

Exit status: 0 clean, 1 problems found, 2 inputs unavailable.
"""

import argparse
import copy
import json
import os
import re
import sys
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
REF_URL = "https://code.claude.com/docs/en/settings-reference.md"
BASE_URL = "https://json.schemastore.org/claude-code-settings.json"

# Written by Claude Code itself and absent from the docs.
RUNTIME_KEYS = {"$schema", "skipWorkflowUsageWarning"}

ROW_RE = re.compile(r"^\| \[`([A-Za-z0-9_.]+)`\]\([^)]*\) \| (.*?) \| (.*?) \| (.*?) \|\s*$", re.M)
SECTION_RE = re.compile(r"^### `([A-Za-z0-9_.]+)`\s*$", re.M)
TYPE_WORDS = {"Boolean": "boolean", "string": "string", "number": "number", "array": "array", "object": "object"}
RETIRED_RE = re.compile(r"^(Deprecated|Removed in)")
IGNORED_SCOPES = {
    "Global config": "lives in ~/.claude.json; settings.json ignores it",
    "Managed": "managed settings only; ignored in user settings",
}


def fetch(url, name):
    cache = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "claude-settings-schema" / name
    try:
        # The docs host returns 403 to urllib's default User-Agent.
        req = urllib.request.Request(url, headers={"User-Agent": "settings_schema.py"})
        with urllib.request.urlopen(req, timeout=15) as r:
            data = r.read().decode()
        cache.parent.mkdir(parents=True, exist_ok=True)
        cache.write_text(data)
        return data
    except OSError as e:
        if cache.exists():
            print(f"warning: {url} unreachable ({e}); using cached copy from {cache}", file=sys.stderr)
            return cache.read_text()
        print(f"error: {url} unreachable and no cached copy ({e})", file=sys.stderr)
        sys.exit(2)


def unlink(md):
    return re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", md)


def parse_type(line, bullets):
    """JSON type names and string enum the docs' `Type:` prose allows.

    Lenient by design: every type word mentioned is allowed, so the prose can
    only ever widen what passes, never flag a valid value.
    """
    types = {TYPE_WORDS[w] for w in re.findall(r"\b(Boolean|string|number|array|object)\b", line)}
    if re.search(r"`(true|false)`", line):
        types.add("boolean")
    enum = None
    m = re.search(r"\bone of(:?)(.*)", line)
    if m and line.startswith("string"):
        if m.group(1):
            enum = [b.group(1) for b in map(re.compile(r'^  \* `"?([^`"]+)"?`').match, bullets) if b]
        else:
            # The list ends at the clause; a later sentence's backticks aren't values.
            clause = re.split(r"\.\s|;", m.group(2))[0]
            enum = [v.strip('"') for v in re.findall(r"`([^`]+)`", clause)]
    return types, enum or None


def parse_docs(ref):
    docs = {}
    for key, desc, _cat, scope in ROW_RE.findall(ref):
        desc = unlink(desc).strip()
        docs[key] = {"desc": desc, "scope": scope.strip(), "types": set(), "enum": None, "retired": desc if RETIRED_RE.search(desc) else None}
    parts = SECTION_RE.split(ref)
    for key, body in zip(parts[1::2], parts[2::2]):
        # Some keys are retired only in their section's <Warning>, under a table row that reads as live.
        warning = re.search(r"<Warning>\s*(.*?)\s*</Warning>", body, re.S)
        if key in docs and warning and RETIRED_RE.search(warning.group(1)) and not docs[key]["retired"]:
            docs[key]["retired"] = unlink(" ".join(warning.group(1).split()))
        lines = body.splitlines()
        for i, line in enumerate(lines):
            if line.startswith("* **Type**: "):
                bullets = []
                for b in lines[i + 1 :]:
                    if not b.startswith("  "):
                        break
                    bullets.append(b)
                types, enum = parse_type(line[len("* **Type**: ") :], bullets)
                if key in docs:
                    docs[key].update(types=types, enum=enum)
                break
    return docs


def json_type(v):
    if isinstance(v, bool):
        return "boolean"
    if isinstance(v, (int, float)):
        return "number"
    return {str: "string", list: "array", dict: "object", type(None): "null"}[type(v)]


def lookup(d, path):
    for part in path.split("."):
        if not isinstance(d, dict) or part not in d:
            return False, None
        d = d[part]
    return True, d


def check(settings, docs):
    problems = []
    top = {k.split(".")[0] for k in docs}
    # ponytail: undocumented-key check is top-level only; nested shapes (permissions, hooks) are the editor schema's job.
    for key in settings:
        if key in RUNTIME_KEYS:
            continue
        if key not in top:
            problems.append(f"{key}: not in the settings reference (typo, or not a settings.json key)")
            continue
        info = docs.get(key)
        if info and info["retired"]:
            problems.append(f"{key}: {info['retired']}")
        if info and info["scope"] in IGNORED_SCOPES:
            problems.append(f"{key}: {IGNORED_SCOPES[info['scope']]}")
    for path, info in docs.items():
        found, v = lookup(settings, path)
        if not found:
            continue
        if info["types"] and json_type(v) not in info["types"]:
            problems.append(f"{path}: is {json_type(v)} {json.dumps(v)}, docs allow {' or '.join(sorted(info['types']))}")
        elif info["enum"] and isinstance(v, str) and v not in info["enum"]:
            problems.append(f"{path}: {json.dumps(v)} is not one of {', '.join(info['enum'])}")
    return problems


def build_schema(base, docs):
    schema = copy.deepcopy(base)
    schema["$comment"] = "Generated by settings_schema.py from json.schemastore.org and the code.claude.com settings reference. Regenerate; don't edit."
    props = schema.setdefault("properties", {})
    for key, info in docs.items():
        if "." in key:
            continue
        if key not in props:
            p = props[key] = {"description": info["desc"]}
            if info["types"]:
                t = sorted(info["types"])
                p["type"] = t[0] if len(t) == 1 else t
            if info["enum"] and info["types"] == {"string"}:
                p["enum"] = info["enum"]
        reason = info["retired"] or IGNORED_SCOPES.get(info["scope"])
        if reason:
            props[key].update(deprecated=True, deprecationMessage=reason)
    return schema


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("files", nargs="*", type=Path)
    ap.add_argument("--ref", type=Path, help="settings-reference.md to use instead of fetching")
    ap.add_argument("--base", type=Path, help="schemastore schema to use instead of fetching")
    ap.add_argument("--out", type=Path, default=HERE / "settings.schema.json")
    args = ap.parse_args()

    ref = args.ref.read_text() if args.ref else fetch(REF_URL, "settings-reference.md")
    base = json.loads(args.base.read_text() if args.base else fetch(BASE_URL, "claude-code-settings.json"))
    docs = parse_docs(ref)
    if not docs:
        print("error: parsed no keys from the settings reference; its table format changed", file=sys.stderr)
        return 2

    args.out.write_text(json.dumps(build_schema(base, docs), indent=2, ensure_ascii=False) + "\n")

    files = args.files or [HERE / "settings.work.json", HERE / "settings.personal.json"]
    bad = 0
    for f in files:
        problems = check(json.loads(f.read_text()), docs)
        if problems:
            bad += 1
            print(f"✗ {f}")
            for p in problems:
                print(f"    {p}")
        else:
            print(f"✓ {f}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
