#!/usr/bin/env python3
"""Claude Code PreToolUse hook: require Touch ID approval for sensitive Bash commands.

Reads the tool-call JSON on stdin. If the Bash command matches a sensitive
pattern, pops a biometric prompt via the `bioprompt` helper (see
bioprompt.swift). Approval -> permissionDecision "allow" (the biometric IS the
permission prompt); denial/timeout -> "deny".

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
from gate_patterns import PATTERNS

BIOPROMPT = os.environ.get("BIOPROMPT", os.path.expanduser("~/.local/bin/bioprompt"))
PROMPT_TIMEOUT_SECS = 90


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

    matched = next(
        (label for regex, label in PATTERNS if re.search(regex, command)),
        None,
    )
    if matched is None:
        sys.exit(0)  # no opinion — normal permission flow

    if sys.platform != "darwin":
        sys.exit(0)  # no Touch ID off-mac; defer to normal flow

    if not os.access(BIOPROMPT, os.X_OK):
        decision("ask", f"[touchid-gate] {matched} — bioprompt helper not compiled "
                        "(run script/claude/setup.sh); falling back to manual approval.")

    try:
        result = subprocess.run(
            [BIOPROMPT, matched, command[:4000]],
            timeout=PROMPT_TIMEOUT_SECS,
            capture_output=True,
        )
    except subprocess.TimeoutExpired:
        decision("deny", f"[touchid-gate] {matched} — biometric prompt timed out.")

    if result.returncode == 0:
        decision("allow", f"[touchid-gate] {matched} — approved via Touch ID.")
    if result.returncode == 2:
        decision("ask", f"[touchid-gate] {matched} — biometric auth unavailable; "
                        "falling back to manual approval.")
    decision("deny", f"[touchid-gate] {matched} — denied via Touch ID prompt.")


if __name__ == "__main__":
    main()
