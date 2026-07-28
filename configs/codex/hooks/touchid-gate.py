#!/usr/bin/env python3
"""Codex PreToolUse hook: biometric-gate high-risk Bash commands on macOS."""

import json
import os
import re
import subprocess
import sys

# This hook is symlinked into ~/.codex/hooks (per-file), so resolve the real
# path first. The canonical pattern list is shared with the Claude hook and
# lives at configs/claude/hooks/gate_patterns.py.
_HERE = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, os.path.join(_HERE, "..", "..", "claude", "hooks"))
from gate_patterns import PATTERNS

BIOPROMPT = os.environ.get("BIOPROMPT", os.path.expanduser("~/.local/bin/bioprompt"))


def deny(reason: str) -> None:
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }}))
    raise SystemExit(0)


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return
    if data.get("tool_name") != "Bash":
        return
    command = (data.get("tool_input") or {}).get("command", "")
    matched = next((label for regex, label in PATTERNS if re.search(regex, command)), None)
    if not matched:
        return

    # Codex's PreToolUse supports only "deny" (no "allow"/"ask"). When biometric
    # approval can't even be attempted — off macOS (the Codex component installs
    # on Arch, where bioprompt never exists) or the helper isn't executable — we
    # emit nothing so Codex's own approval policy (approval_policy = "on-request"
    # still prompts the user) applies. This is a tripwire, not the enforcement
    # layer; deny() is reserved for a real biometric timeout or denial below.
    if sys.platform != "darwin" or not os.access(BIOPROMPT, os.X_OK):
        return
    try:
        result = subprocess.run([BIOPROMPT, matched, command[:4000]], timeout=90, capture_output=True)
    except subprocess.TimeoutExpired:
        deny(f"[touchid-gate] {matched} — biometric prompt timed out")
    if result.returncode != 0:
        deny(f"[touchid-gate] {matched} — biometric approval denied or unavailable")
    # No output means the hook has no further opinion. The normal Codex
    # sandbox/rules policy still applies after biometric approval.


if __name__ == "__main__":
    main()
