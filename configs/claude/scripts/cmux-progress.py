#!/usr/bin/env python3
"""Drive the cmux sidebar progress bar from Claude Code's task list.

On every TodoWrite, render completed/total as a 0.0-1.0 sidebar bar labelled
with the in-progress task — so across many workspaces you can see at a glance
which agent is 20% vs 90% through a plan or a Ralph/PRD run.

Triggers (see settings.json):
  PostToolUse(TodoWrite)  — recompute the bar from tool_input.todos
  SessionStart            — clear the bar (fresh session, no stale fraction)

A finished list sits at 100% until the next TodoWrite resets it or the next
session clears it. Deliberately NOT cleared on Stop: a mid-task bar must
survive between turns.

Cosmetic: every failure path exits 0; it must never break a session.
"""
import sys, os, json

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cmux_common as cx

DONE_LABEL = "Done"
COMPLETED = "completed"
IN_PROGRESS = "in_progress"
PENDING = "pending"


def _label(todos):
    """Active-task label: in-progress (activeForm preferred) > next pending > Done."""
    for want in (IN_PROGRESS, PENDING):
        for t in todos:
            if t.get("status") == want:
                return t.get("activeForm") or t.get("content") or DONE_LABEL
    return DONE_LABEL


def progress_for(todos):
    """Pure mapping: todo list -> the cmux action to take.

    Returns {"action": "clear"} for an empty list, else
    {"action": "set", "fraction": <0.0-1.0 str>, "label": <text>}.
    Side-effect-free so the test suite can assert it directly.
    """
    if not todos:
        return {"action": "clear"}
    total = len(todos)
    completed = sum(1 for t in todos if t.get("status") == COMPLETED)
    return {"action": "set", "fraction": f"{completed / total:.2f}",
            "label": _label(todos)}


def apply(uuid, p):
    if p["action"] == "set":
        cx.run([cx.CLI, "set-progress", p["fraction"],
                "--label", p["label"], "--workspace", uuid])
    else:
        cx.run([cx.CLI, "clear-progress", "--workspace", uuid])


def main():
    # Hidden test hook: read a todos JSON array on stdin, print the action.
    if len(sys.argv) >= 2 and sys.argv[1] == "--emit":
        try:
            todos = json.load(sys.stdin)
        except Exception:
            todos = []
        p = progress_for(todos)
        print(p["action"] if p["action"] == "clear"
              else "\t".join(["set", p["fraction"], p["label"]]))
        return

    if not cx.alive():
        return
    d = cx.read_stdin()
    uuid, _session, _gsid = cx.resolve_workspace(d.get("session_id", ""))
    if not uuid:
        return

    # SessionStart (or --clear) clears; PostToolUse(TodoWrite) computes.
    event = d.get("hook_event_name", "")
    if "--clear" in sys.argv or event == "SessionStart":
        apply(uuid, {"action": "clear"})
        return
    todos = d.get("tool_input", {}).get("todos", [])
    apply(uuid, progress_for(todos))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
