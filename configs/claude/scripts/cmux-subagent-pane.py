#!/usr/bin/env python3
"""Mirror each Claude Code subagent into its own cmux pane.

Modes:
  hook  SubagentStart: resolve the agent's transcript from the hook JSON on
        stdin and spawn `pane` detached (the hook runs inline with agent start).
  pane  open a cmux pane and launch `view` inside it.
  view  runs inside the pane; renders the agent's jsonl as it streams.

SubagentStart hands us agent_id, and a subagent's transcript is always
<project>/<session>/subagents/agent-<agent_id>.jsonl -- confirmed by the
agent_transcript_path that SubagentStop reports for the same id. So each pane
maps to its agent exactly, with no polling or guessing, and parallel dispatches
need no coordination.
"""

import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import textwrap
import time

CLI = "/Applications/cmux.app/Contents/Resources/bin/cmux"
SELF = os.path.abspath(__file__)

POLL = 0.2
META_WAIT = 5.0  # meta.json is written moments after the jsonl appears

DIM = "\033[2m"
BOLD = "\033[1m"
CYAN = "\033[36m"
GREEN = "\033[32m"
RESET = "\033[0m"

# First key present wins; ordered so the most identifying argument is picked.
LABEL_KEYS = (
    "file_path", "command", "pattern", "url", "query",
    "path", "skill", "description", "prompt",
)


def cmux(*args):
    return subprocess.run(
        [CLI, "--id-format", "both", *args],
        capture_output=True, text=True, timeout=15,
    ).stdout


def agent_transcript(payload):
    """<project>/<session>.jsonl + agent_id -> the subagent's own transcript."""
    transcript = payload.get("transcript_path")
    agent_id = payload.get("agent_id")
    if not transcript or not agent_id:
        return None
    return os.path.join(
        os.path.splitext(transcript)[0], "subagents", "agent-%s.jsonl" % agent_id
    )


# ---------------------------------------------------------------- hook


def hook():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return
    path = agent_transcript(payload)
    if not path:
        return
    subprocess.Popen(
        [sys.executable, SELF, "pane", path],
        start_new_session=True,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


# ---------------------------------------------------------------- pane


def read_meta(path):
    meta_path = path[: -len(".jsonl")] + ".meta.json"
    deadline = time.time() + META_WAIT
    while time.time() < deadline:
        try:
            with open(meta_path) as f:
                return json.load(f)
        except (OSError, ValueError):
            time.sleep(POLL)
    return {}


def pane(path):
    meta = read_meta(path)
    title = meta.get("description") or meta.get("agentType") or "subagent"

    # ponytail: one pane per agent, split right. Many concurrent agents => thin
    # panes; switch to `new-surface --pane <agents-pane>` (tabs in one pane) if
    # that bites.
    args = ["new-pane", "--type", "terminal", "--direction", "right", "--focus", "false"]
    workspace = os.environ.get("CMUX_WORKSPACE_ID")
    if workspace:
        # Without this cmux falls back to the *focused* workspace, which drifts
        # as the user clicks around.
        args += ["--workspace", workspace]
    out = cmux(*args)

    # Refs (surface:39) are indices that renumber as panes open/close, so a
    # concurrent dispatch can shift one onto another surface. Use the UUID.
    match = re.search(r"surface:\d+ \(([0-9A-Fa-f-]{36})\)", out)
    if not match:
        return
    surface = match.group(1)

    cmd = "clear && {} {} view {}".format(
        shlex.quote(sys.executable), shlex.quote(SELF), shlex.quote(path)
    )
    cmux("send", "--surface", surface, cmd)
    cmux("send-key", "--surface", surface, "Enter")
    cmux("rename-tab", "--surface", surface, title[:40])


# ---------------------------------------------------------------- view


def width():
    return max(40, shutil.get_terminal_size((80, 24)).columns - 2)


def wrap(text, indent="", limit=None):
    out = []
    for para in text.split("\n"):
        if not para.strip():
            out.append("")
            continue
        out += textwrap.wrap(
            para, width=width() - len(indent), initial_indent=indent,
            subsequent_indent=indent, break_long_words=False, break_on_hyphens=False,
        ) or [""]
    if limit and len(out) > limit:
        out = out[:limit] + [indent + DIM + "..." + RESET]
    return "\n".join(out)


def label(tool_input):
    if not isinstance(tool_input, dict):
        return ""
    for key in LABEL_KEYS:
        val = tool_input.get(key)
        if isinstance(val, str) and val.strip():
            val = " ".join(val.split())
            if key in ("file_path", "path"):
                if val.startswith("/"):
                    val = os.path.relpath(val, os.getcwd())
                # Keep the tail: the basename is what identifies a path.
                return val if len(val) <= 50 else "..." + val[-47:]
            return val if len(val) <= 60 else val[:57] + "..."
    return ""


def render(record):
    """Print one jsonl record. Returns True when the agent has finished."""
    try:
        rec = json.loads(record)
    except ValueError:
        return False
    msg = rec.get("message")
    if not isinstance(msg, dict):
        return False  # attachments and other non-message records
    content = msg.get("content")

    if msg.get("role") == "user":
        if isinstance(content, str):  # the dispatch prompt
            print(DIM + wrap(content.strip(), "  ", limit=8) + RESET + "\n", flush=True)
        return False  # tool_result: noise in a narrow pane

    if msg.get("role") != "assistant":
        return False

    used_tool = False
    for block in content if isinstance(content, list) else []:
        if not isinstance(block, dict):
            continue
        if block.get("type") == "text":
            text = block.get("text", "").strip()
            if text:
                print(wrap(text) + "\n", flush=True)
        elif block.get("type") == "tool_use":
            used_tool = True
            arg = label(block.get("input"))
            print(
                "{}⏺{} {}{}{}{}".format(
                    GREEN, RESET, BOLD, block.get("name", "?"), RESET,
                    DIM + "(" + arg + ")" + RESET if arg else "",
                ),
                flush=True,
            )

    # The agent loop only ends when it stops calling tools, so text with
    # end_turn and no tool_use is the final answer.
    return msg.get("stop_reason") == "end_turn" and not used_tool


def view(path):
    meta = read_meta(path)
    bar = "─" * width()
    print(
        "{}{}{}\n{}{}{} {}{}{}\n{}{}{}\n".format(
            CYAN, bar, RESET,
            BOLD + CYAN, meta.get("agentType", "agent"), RESET,
            DIM, meta.get("description", ""), RESET,
            CYAN, bar, RESET,
        ),
        flush=True,
    )

    while not os.path.exists(path):
        time.sleep(POLL)

    started = time.time()
    buf = ""
    with open(path, "r", errors="replace") as f:
        while True:
            chunk = f.read()
            if not chunk:
                time.sleep(POLL)
                continue
            buf += chunk
            while "\n" in buf:
                line, buf = buf.split("\n", 1)
                if render(line):
                    print(
                        "{}{}{}\n{}✓ done{} {}in {:.0f}s{}".format(
                            CYAN, bar, RESET, GREEN, RESET,
                            DIM, time.time() - started, RESET,
                        ),
                        flush=True,
                    )
                    return


# ---------------------------------------------------------------- main


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "hook"
    if mode == "hook":
        hook()
    elif mode == "pane":
        pane(sys.argv[2])
    elif mode == "view":
        try:
            view(sys.argv[2])
        except KeyboardInterrupt:
            pass
    else:
        sys.exit("usage: cmux-subagent-pane.py [hook|pane FILE|view FILE]")


if __name__ == "__main__":
    main()
