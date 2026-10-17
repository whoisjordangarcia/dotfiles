#!/usr/bin/env python3
"""memory-stale — report Claude Code auto-memories (~/.claude/projects/*/memory) that are likely stale.

Read-only. Flags, per memory file:
  DEAD   a backticked ~/… or /home/… path (globs ok) that no longer exists
  DEAD?  same, for a path relative to the project's cwd (lower confidence: it may be relative to another repo)
  OLD    `modified:` (or mtime) older than DAYS (default 45)
  LINK   a [[link]] to a memory name that doesn't exist in the same project
  INDEX  file not listed in MEMORY.md, or MEMORY.md lists a missing file
and per project: GONE (the project's cwd no longer exists, e.g. a /tmp test session).

Usage: memory-stale [DAYS]       exit 1 if anything was flagged
"""
import datetime as dt, glob, json, os, re, sys

DAYS = int(sys.argv[1]) if len(sys.argv) > 1 else 45
HOME = os.path.expanduser("~")
now = dt.datetime.now(dt.timezone.utc)


def project_cwd(pdir):
    # Session transcripts record the real cwd; the dir name is ambiguous ("dev-notes" vs "dev/notes").
    for j in glob.glob(os.path.join(pdir, "*.jsonl")):
        with open(j, errors="ignore") as f:
            for line in f:
                if '"cwd"' in line:
                    try:
                        return json.loads(line)["cwd"]
                    except (ValueError, KeyError):
                        pass
    return None


def paths_in(text, cwd):
    for tok in re.findall(r"`([^`\s]+)`", text):
        tok = re.sub(r":\d+$", "", tok.rstrip(".,;)"))
        if "<" in tok:  # `snapshot-<id>.sh` is a placeholder, not a path
            continue
        if tok.startswith("~/"):
            yield "DEAD ", tok, os.path.join(HOME, tok[2:])
        elif tok.startswith("/home/"):
            yield "DEAD ", tok, tok
        # ponytail: relative = has a slash and a file extension; skips globs/URLs/flags, misses extensionless dirs
        elif cwd and re.fullmatch(r"[\w.-]+(/[\w.-]+)+\.\w+", tok):
            yield "DEAD?", tok, os.path.join(cwd, tok)


flagged = 0
for mdir in sorted(glob.glob(os.path.join(HOME, ".claude/projects/*/memory"))):
    pdir = os.path.dirname(mdir)
    cwd = project_cwd(pdir)
    files = sorted(f for f in os.listdir(mdir) if f.endswith(".md") and f != "MEMORY.md")
    out = []
    if cwd and not os.path.isdir(cwd):
        out.append(f"GONE   project cwd {cwd} no longer exists: rm -r '{pdir}'")

    index = open(os.path.join(mdir, "MEMORY.md")).read() if os.path.exists(os.path.join(mdir, "MEMORY.md")) else ""
    indexed = set(re.findall(r"\]\(([^)]+\.md)\)", index))
    out += [f"INDEX  MEMORY.md -> {f} (missing file)" for f in sorted(indexed - set(files))]
    names = set()
    for f in files:
        m = re.search(r"^name:\s*(\S+)", open(os.path.join(mdir, f)).read(), re.M)
        names.add(m.group(1) if m else f[:-3])

    for f in files:
        path = os.path.join(mdir, f)
        text = open(path).read()
        m = re.search(r"modified:\s*(\S+)", text)
        when = dt.datetime.fromisoformat(m.group(1).replace("Z", "+00:00")) if m else \
            dt.datetime.fromtimestamp(os.path.getmtime(path), dt.timezone.utc)
        age = (now - when).days
        issues = []
        if f not in indexed:
            issues.append("INDEX  not in MEMORY.md (never loaded)")
        if age > DAYS:
            issues.append(f"OLD    {age}d since modified")
        seen = set()
        for tag, tok, p in paths_in(text, cwd):
            if tok not in seen and not glob.glob(p):
                seen.add(tok)
                issues.append(f"{tag}  `{tok}`")
        # slug-only so bash `[[ -z $X ]]` in code isn't read as a link
        issues += [f"LINK   [[{l}]]" for l in sorted(set(re.findall(r"\[\[([\w-]+)(?:\|[^\]]*)?\]\]", text)) - names)]
        if issues:
            out.append(f"{f}  ({age}d)")
            out += ["    " + i for i in issues]

    if out:
        flagged += 1
        print(f"\n## {cwd or os.path.basename(pdir)}  [{mdir}]")
        print("\n".join(out))

if flagged:
    print("\nDEAD/GONE/INDEX are near-certain; DEAD? and LINK need a look; OLD alone only means 're-verify before trusting'.")
sys.exit(1 if flagged else 0)
