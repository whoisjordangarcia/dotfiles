#!/usr/bin/env python3
"""SessionStart/SessionEnd hook: remember which Claude chat runs in each Rex pane.

Writes the chat id to <state>/claude/<block>. After Rex restores the pane,
.zshrc.rex-resume reruns the pane's claude command with --resume <that id>.
"""
import json
import os
import subprocess
import sys

STATE_DIR = os.path.expanduser(os.environ.get("REX_RESUME_STATE_DIR", "~/.local/state/rex-resume"))

# Only an explicit quit forgets the chat. A reboot or server stop kills claude
# with a signal, and the entry must survive that for the restore.
FORGET_REASONS = {"prompt_input_exit", "logout"}


def parent_and_name(pid):
    out = subprocess.run(["ps", "-o", "ppid=,comm=", "-p", str(pid)], capture_output=True, text=True)
    parts = out.stdout.strip().split(None, 1)
    return (int(parts[0]), parts[1] if len(parts) > 1 else "") if parts else (0, "")


def owns_pane(session, block):
    """True when the nearest claude above this hook is the pane's foreground process.

    A `claude -p` started from inside the pane's chat inherits REX_BLOCK, but its
    nearest claude ancestor is itself, not the pane's foreground claude.
    """
    out = subprocess.run(
        ["rex", "--autostart=false", "block", "call", "-s", session, "-b", block, "process"],
        capture_output=True, text=True, timeout=5,
    )
    if out.returncode != 0:
        return False
    foreground = (json.loads(out.stdout).get("foreground") or {}).get("pid")
    pid = os.getppid()
    for _ in range(12):
        if not foreground or pid <= 1:
            return False
        if pid == foreground:
            return True
        pid, name = parent_and_name(pid)
        if "claude" in name:
            return False
    return False


def main():
    block, session = os.environ.get("REX_BLOCK"), os.environ.get("REX_SESSION")
    if not block or not session:
        return
    event = json.load(sys.stdin)
    chat = event.get("session_id")
    if not chat:
        return
    path = os.path.join(STATE_DIR, "claude", block.removeprefix("block:"))

    if event.get("hook_event_name") == "SessionEnd":
        if event.get("reason") in FORGET_REASONS:
            try:
                with open(path) as f:
                    if f.read().strip() == chat:
                        os.remove(path)
            except FileNotFoundError:
                pass
        return

    if not owns_pane(session, block):
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        f.write(chat + "\n")
    os.replace(tmp, path)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # a broken tracker must never block a Claude session
        print(f"rex-resume-track: {exc}", file=sys.stderr)
