#!/usr/bin/env python3
"""Show a cmux sidebar pill when this branch's PR is approved.

CI status is intentionally left to cmux's native PR watcher (it already
populates the sidebar `pr` field). This script owns the one signal the native
watcher doesn't surface: that a human approved the PR.

  reviewDecision == APPROVED  ->  set-status review "✓ Approved #<n>"
  anything else / no PR       ->  clear-status review   (idempotent — no stale pill)

Triggers (see settings.json):
  SessionStart / Stop                       — refresh at session start + turn-end
  PostToolUse(Bash) after git push / gh pr  — refresh right after you push/open a PR

Cosmetic: every failure path exits 0; it must never break a session.
"""
import sys, os, json

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cmux_common as cx

STATUS_KEY = "review"
APPROVED = "APPROVED"
PILL_ICON = "checkmark.seal.fill"
PILL_COLOR = "#3FB950"  # GitHub green
PILL_PRIORITY = "20"


def review_pill(review_decision, number):
    """Pure mapping: PR review state -> the cmux action to take.

    Returns a dict the caller turns into a `cmux` invocation, or one that clears
    the pill. Kept side-effect-free so the test suite can assert it directly.
    """
    if review_decision == APPROVED:
        label = f"✓ Approved #{number}" if number else "✓ Approved"
        return {"action": "set", "value": label, "icon": PILL_ICON,
                "color": PILL_COLOR, "priority": PILL_PRIORITY}
    return {"action": "clear"}


def gh_pr_info(cwd):
    """(reviewDecision, number) for the cwd's branch PR, or (None, None).

    Any failure — no PR, not a repo, gh unauthenticated — is 'no PR'.
    """
    r = cx.run(["gh", "pr", "view", "--json", "number,reviewDecision,url"])
    if r.returncode != 0 or not r.stdout.strip():
        return None, None
    try:
        d = json.loads(r.stdout)
    except Exception:
        return None, None
    return d.get("reviewDecision") or "", d.get("number")


def apply(uuid, pill):
    if pill["action"] == "set":
        cx.run([cx.CLI, "set-status", STATUS_KEY, pill["value"],
                "--icon", pill["icon"], "--color", pill["color"],
                "--priority", pill["priority"], "--workspace", uuid])
    else:
        cx.run([cx.CLI, "clear-status", STATUS_KEY, "--workspace", uuid])


def main():
    # Hidden test hook: print the action for a given state without touching cmux.
    if len(sys.argv) >= 2 and sys.argv[1] == "--emit":
        decision = sys.argv[2] if len(sys.argv) > 2 else ""
        number = sys.argv[3] if len(sys.argv) > 3 else ""
        p = review_pill(decision, number)
        print(p["action"] if p["action"] == "clear"
              else "\t".join(["set", p["value"], p["color"], p["priority"]]))
        return

    if not cx.alive():
        return
    # gh runs in the dir the hook fired from.
    d = cx.read_stdin()
    cwd = d.get("cwd") or os.getcwd()
    os.chdir(cwd) if os.path.isdir(cwd) else None

    uuid, _session, _gsid = cx.resolve_workspace(d.get("session_id", ""))
    if not uuid:
        return
    decision, number = gh_pr_info(cwd)
    apply(uuid, review_pill(decision, number))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
