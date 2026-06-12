#!/usr/bin/env python3
"""Keep this Claude session's cmux workspace title in sync.

Title auto-tracks the topic: Claude Code sets the terminal *surface* title to a live
topic summary; this reads it (stripping status glyphs), prefixes the detected Linear
ticket, and pins it as the workspace title — updating on every turn, no manual step
required.

Triggers (all wired as hooks; see settings.json):
  SessionStart / CwdChanged / Stop — stdin {session_id, cwd}
  Manual override of the topic:  cmux-title.py --topic "short topic"

Title:        "NES-#### · <topic>" — no worktree fallback: before the first
              topic exists the title is just the ticket (or left untouched when
              there's no ticket). The description is NOT managed (cmux shows
              the workspace location natively).

Manual override: remembers the last title it set; if you rename the workspace in
cmux, the next run sees current != last-set and backs off — your title is kept.

Cosmetic: every failure path exits 0; it must never break a session.
"""
import sys, os, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cmux_common as cx

TICKET_RE = re.compile(r"\bNES-\d+\b", re.I)
import glob, json


def detect_ticket(session_id, cwd):
    """Most-recent NES-#### the USER typed (assistant prose + tool results skipped;
    injected <system-reminder> context stripped — both are false-positive sources)."""
    if session_id:
        hits = glob.glob(os.path.expanduser(f"~/.claude/projects/**/{session_id}.jsonl"), recursive=True)
        transcript = hits[0] if hits else ""
    else:
        proj = os.path.expanduser("~/.claude/projects/" + re.sub(r"[/.]", "-", cwd))
        js = sorted(glob.glob(proj + "/*.jsonl"), key=os.path.getmtime, reverse=True)
        transcript = js[0] if js else ""
    if not transcript or not os.path.isfile(transcript):
        return ""
    found = []
    with open(transcript) as f:
        for line in f:
            try:
                e = json.loads(line)
            except Exception:
                continue
            if e.get("type") != "user":
                continue
            c = e.get("message", {}).get("content")
            if not isinstance(c, str):
                continue
            c = re.sub(r"<system-reminder>.*?</system-reminder>", "", c, flags=re.S)
            found += TICKET_RE.findall(c)
    return found[-1].upper() if found else ""


def surface_topic(uuid, worktree):
    """The live topic from Claude Code's terminal surface title, cleaned up.

    Returns '' when the title is empty, a path, or just the worktree name — i.e. not
    yet a real topic — so the caller falls back to the worktree.
    """
    # NOTE: raw rpc requires the UUID key "workspace_id"; the friendly "workspace"
    # key is silently ignored and returns the *focused* workspace instead.
    try:
        d = json.loads(cx.run([cx.CLI, "rpc", "surface.list", json.dumps({"workspace_id": uuid})]).stdout)
    except Exception:
        return ""
    for s in d.get("surfaces", []):
        if s.get("type") != "terminal":
            continue
        t = re.sub(r"^[^0-9A-Za-z]+", "", s.get("title", "") or "").strip()
        if not t or t.startswith("/") or t == worktree or t.lower() in ("zsh", "bash"):
            return ""
        return t
    return ""


def main():
    if not cx.alive():
        return
    topic, argv = "", sys.argv[1:]
    for i, v in enumerate(argv):
        if v == "--topic" and i + 1 < len(argv):
            topic = argv[i + 1]

    d = cx.read_stdin()
    cwd = d.get("cwd") or os.getcwd()
    uuid, session_id, gsid = cx.resolve_workspace(d.get("session_id", ""))
    if not uuid:
        return

    # worktree name — only used by surface_topic to reject not-yet-a-topic titles
    top = cx.run(["git", "-C", cwd, "rev-parse", "--show-toplevel"]).stdout.strip()
    worktree = os.path.basename(top or cwd)

    # label: explicit topic > live surface topic. No worktree fallback — the
    # description already shows worktree+branch, so before the first topic the
    # title is just the ticket (or untouched when there's no ticket either).
    label = topic or surface_topic(uuid, worktree)
    ticket = detect_ticket(session_id, cwd)
    if label:
        title = f"{ticket} · {label}" if ticket else label
    else:
        title = ticket

    # respect a manual override (state keyed by the terminal)
    current = next((w.get("title", "") for w in cx.workspaces() if w.get("id") == uuid), "")
    statefile = os.path.join(cx.MAP_DIR, f"{gsid}.title") if gsid else ""
    last_set = open(statefile).read() if statefile and os.path.isfile(statefile) else ""
    if last_set and current != last_set:
        return

    base = [cx.CLI, "workspace-action", "--workspace", uuid]
    if title:
        cx.run(base + ["--action", "rename", "--title", title])
    if title and statefile:
        try:
            with open(statefile, "w") as f:
                f.write(title)
        except Exception:
            pass


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
