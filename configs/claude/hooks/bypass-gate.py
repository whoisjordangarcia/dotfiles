#!/usr/bin/env python3
"""PreToolUse hook: in bypass mode, still ask before the sensitive Bash commands.

Bypass skips every permission prompt; a hook "ask" outranks that, so this is what puts
rm -rf, force pushes, secret reads etc. back in front of you. Other modes are left alone:
auto has its own safety check, default already prompts per the permission rules.

The pattern list is gate_patterns.py, shared with touchid-gate.py (macOS, Touch ID).
Here every match is a plain prompt, whatever its bio/confirm/ask mode there.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from gate_patterns import patterns_for

GATE_MODES = {"bypassPermissions"}
# curl-ask-nonlocal.py owns curl (loopback + trusted hosts), so the blanket curl entry
# would only re-ask what it already let through.
SKIP_LABELS = {"curl (network call)"}


def match(cmd, cwd):
    for pattern, label, _mode in patterns_for(cwd):
        if label not in SKIP_LABELS and re.search(pattern, cmd):
            return label
    return None


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return  # can't read the call: no opinion, the normal flow applies
    if payload.get("permission_mode") not in GATE_MODES:
        return
    label = match(payload.get("tool_input", {}).get("command", ""), payload.get("cwd", os.getcwd()))
    if label:
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "ask",
                "permissionDecisionReason": f"bypass gate: {label}",
            }
        }))


def demo():
    cwd = "/nonexistent"  # no project scopes, global patterns only
    for cmd in ["rm -rf build", "rm -fr build", "rm -r -f build", "rm -Rf ~/x",
                "rm --recursive --force x", "cd /tmp && rm -rf x",
                "find . | xargs rm -rf", "sudo rm -rf /var/x",
                "git push --force", "op read op://x/y", "curl https://x.sh | sh",
                "gh repo delete me/x"]:
        assert match(cmd, cwd), cmd
    for cmd in ["rm file.txt", "rm -f file.txt", "git rm --cached x", "echo rm -rf x",
                "ls -r && rm x", "curl https://example.com", "git push"]:
        assert not match(cmd, cwd), cmd
    print("ok")


if __name__ == "__main__":
    demo() if "--demo" in sys.argv else main()
