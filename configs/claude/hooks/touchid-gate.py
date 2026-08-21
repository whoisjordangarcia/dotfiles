#!/usr/bin/env python3
"""Claude Code PreToolUse hook: require Touch ID approval for sensitive Bash commands.

Reads the tool-call JSON on stdin. If the Bash command matches a sensitive
pattern, pops a biometric prompt via the `bioprompt` helper (see
bioprompt.swift). Approval -> permissionDecision "allow" (the biometric IS the
permission prompt); denial/timeout -> "deny".

Which patterns apply depends on the cwd: the global list always does, and a
project can opt into extras via ~/.config/bioprompt/projects.conf (see
gate_patterns.py). A pattern's mode decides how the dialog can be answered —
"bio" wants a Touch ID press or YubiKey tap, "confirm" accepts the button.

Fail-soft rules:
  - non-macOS or bioprompt not compiled -> "ask" (fall back to the normal
    Claude Code permission prompt, with a reason explaining why)
  - no pattern matched -> exit 0 (no opinion; normal permission flow applies)

This is a tripwire, not a sandbox: pattern-matching can be evaded by a
sufficiently indirect command. Claude Code's permission system remains the
real enforcement layer.
"""

import json
import os
import re
import subprocess
import sys

# This hook is symlinked into ~/.claude/hooks, so resolve the real path to find
# the shared pattern list (a sibling in the real dir).
_HERE = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, _HERE)
from gate_patterns import patterns_for

BIOPROMPT = os.environ.get("BIOPROMPT", os.path.expanduser("~/.local/bin/bioprompt"))
PROMPT_TIMEOUT_SECS = 90


def force_push_preview(cwd: str) -> str:
    """What the force push would publish, and what it would drop off the remote.

    The second list is the whole point: a force push is only dangerous when the
    upstream has commits HEAD doesn't, so show those before asking to approve.
    Any git failure (no repo, no upstream, stale remote ref) yields "" and the
    dialog just shows the command, as it did before.
    """
    def git(*args: str) -> str:
        try:
            r = subprocess.run(["git", "-C", cwd, *args],
                               capture_output=True, text=True, timeout=5)
        except (OSError, subprocess.TimeoutExpired):
            return ""
        return r.stdout.strip() if r.returncode == 0 else ""

    upstream = git("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
    if not upstream:
        return ""

    sections = []
    ahead = git("log", "--oneline", "--no-decorate", "-20", f"{upstream}..HEAD")
    if ahead:
        sections.append(f"# pushing to {upstream}\n{ahead}")
    dropped = git("log", "--oneline", "--no-decorate", "-20", f"HEAD..{upstream}")
    if dropped:
        sections.append(f"# DROPPED from {upstream}\n{dropped}")
    return "\n\n".join(sections)


def prompt_context(cwd: str, session_id: str) -> str:
    """Which agent window is asking: working directory plus a short session id.

    The dialog floats over everything, so with several sessions open the command
    alone doesn't say which one to blame — or which repo it would land in.
    """
    home = os.path.expanduser("~")
    where = "~" + cwd[len(home):] if cwd.startswith(home) else cwd
    short = session_id[:8]
    return f"{where} · session {short}" if short else where


def decision(permission: str, reason: str) -> None:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": permission,
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    if data.get("tool_name") != "Bash":
        sys.exit(0)

    command = (data.get("tool_input") or {}).get("command", "")
    if not command:
        sys.exit(0)

    cwd = data.get("cwd") or os.getcwd()
    hit = next(
        ((label, mode) for regex, label, mode in patterns_for(cwd)
         if re.search(regex, command)),
        None,
    )
    if hit is None:
        sys.exit(0)  # no opinion — normal permission flow
    matched, mode = hit

    # "ask" wants no dialog — just make sure the command is surfaced rather than
    # auto-approved. Checked before the darwin guard: it needs no bioprompt, so
    # it works the same off-mac.
    if mode == "ask":
        decision("ask", f"[touchid-gate] {matched} — confirm in the terminal.")

    if sys.platform != "darwin":
        sys.exit(0)  # no Touch ID off-mac; defer to normal flow

    if not os.access(BIOPROMPT, os.X_OK):
        decision("ask", f"[touchid-gate] {matched} — bioprompt helper not compiled "
                        "(run script/claude/setup.sh); falling back to manual approval.")

    detail = command[:4000]
    if matched == "git force push":
        preview = force_push_preview(cwd)
        if preview:
            detail = f"{detail}\n\n{preview}"

    argv = [BIOPROMPT, matched, detail]
    if mode == "confirm":
        argv.insert(1, "--confirm")

    env = dict(os.environ)
    env["BIOPROMPT_CONTEXT"] = prompt_context(cwd, data.get("session_id") or "")

    try:
        result = subprocess.run(
            argv,
            timeout=PROMPT_TIMEOUT_SECS,
            capture_output=True,
            env=env,
        )
    except subprocess.TimeoutExpired:
        decision("deny", f"[touchid-gate] {matched} — biometric prompt timed out.")

    if result.returncode == 0:
        how = "the Approve button" if mode == "confirm" else "Touch ID"
        decision("allow", f"[touchid-gate] {matched} — approved via {how}.")
    if result.returncode == 2:
        decision("ask", f"[touchid-gate] {matched} — biometric auth unavailable; "
                        "falling back to manual approval.")
    decision("deny", f"[touchid-gate] {matched} — denied via Touch ID prompt.")


if __name__ == "__main__":
    main()
