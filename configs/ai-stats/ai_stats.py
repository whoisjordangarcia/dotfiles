#!/usr/bin/env python3
"""ai-stats: interactive TUI of Claude plan limits, usage, cost, skills and activity. --json for bar widgets."""
import json
import os
import re
import select
import sqlite3
import sys
import termios
import time
import tty
from collections import Counter, defaultdict, namedtuple
from datetime import datetime, timedelta
from functools import lru_cache
from pathlib import Path

CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "ai-stats"
CACHE = CACHE_DIR / "statusline.json"
HISTORY = CACHE_DIR / "limits.log"
PROJECTS = Path.home() / ".claude" / "projects"
REFRESH_SECS = 30
DAYS = 30
RANGES = {"7": 7, "3": 30, "9": 90, "a": 365}
METRICS = ("tokens", "cost", "lines")
PANELS = ("models", "agents", "sessions", "skills", "tools", "projects", "hours", "limits", "speed")
WEEKDAYS = ("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")

BOLD, DIM, RESET = "\033[1m", "\033[2m", "\033[0m"
GREEN, YELLOW, RED, MAGENTA = "\033[32m", "\033[33m", "\033[31m", "\033[35m"
BLOCKS = " ▁▂▃▄▅▆▇█"
SHADES = " ░▒▓█"
LABELS = {"five_hour": "Session (5h)", "seven_day": "Week (7d)"}
LEFT, RIGHT = ("\x1b[D", "h"), ("\x1b[C", "l")
MOUSE_ON, MOUSE_OFF = "\033[?1000h\033[?1006h", "\033[?1006l\033[?1000l"
MOUSE_RE = re.compile(r"\033\[<(\d+);(\d+);(\d+)([Mm])")
RANGE_CHIPS = ((7, "7d"), (30, "30d"), (90, "90d"), (365, "all"))
# Filled by render(), read by the mouse handler: 1-based (row, col) spans of the clickable chrome.
HITS = {"range": [], "panel": [], "chart": None}
SERIES_COLORS = {"opus": "35", "fable": "36", "sonnet": "34", "haiku": "32", "added": "32", "removed": "31",
                 "week": "35", "session": "36", "codex": "33", "opencode": "32", "cursor": "31"}
COMMAND_RE = re.compile(r"<command-name>/?([^<\s]+)</command-name>")

# $/MTok (input, output, cache read); first prefix match wins. Cache writes bill 1.25x input (5m) or 2x (1h).
# ponytail: only models seen in recent transcripts; Opus 4.1 and older would price at Opus 5 rates.
PRICES = (
    ("claude-fable-5-1", 10, 50, 0.25),
    ("claude-fable", 10, 50, 1.0),
    ("claude-opus", 5, 25, 0.5),
    ("claude-sonnet-5", 2, 10, 0.2),
    ("claude-sonnet", 3, 15, 0.3),
    ("claude-haiku", 1, 5, 0.1),
)

Usage = namedtuple("Usage", "key ts day weekday hour fam model tokens output thinking cost input cache_read session project worktree subagent tool")
Lines = namedtuple("Lines", "key day project added removed")
Skill = namedtuple("Skill", "key day name typed")
Tool = namedtuple("Tool", "key day name")
Prompt = namedtuple("Prompt", "key ts session text")


def series_color(name, faint=False):
    return f"\033[0;{'2;' if faint else ''}{SERIES_COLORS.get(name, '33')}m"


def fmt_tokens(n):
    for div, unit in ((1e9, "B"), (1e6, "M"), (1e3, "k")):
        if n >= div:
            return f"{n / div:.1f}{unit}"
    return str(int(n))


def fmt_cost(v):
    return f"${v:,.0f}" if v >= 100 else f"${v:.2f}"


def fmt_duration(secs):
    if secs <= 0:
        return "now"
    if secs < 60:
        return "<1m"
    d, rem = divmod(int(secs), 86400)
    h, m = rem // 3600, rem % 3600 // 60
    return f"{d}d{h}h" if d else f"{h}h{m:02d}m" if h else f"{m}m"


def load_limits():
    """Return (rate_limits, cache mtime); ({}, None) until a session has rendered its statusline."""
    try:
        return json.loads(CACHE.read_text()).get("rate_limits") or {}, CACHE.stat().st_mtime
    except (OSError, ValueError):
        return {}, None


def load_history(now, span=7 * 86400):
    """Return [(epoch, session %, week %)] from the statusline's sample log, oldest first."""
    try:
        text = HISTORY.read_text()
    except OSError:
        return []
    out = []
    for ln in text.splitlines():
        try:
            t, s, w = (float(x) for x in ln.split())
        except ValueError:
            continue
        if now - t <= span:
            out.append((t, s, w))
    return out


def window_secs(key):
    return {"five_hour": 5 * 3600}.get(key) or (7 * 86400 if key.startswith("seven_day") else None)


def projected(pct, reset, now, window):
    """Percentage at reset if the current rate holds; None when the window is unknown or under 5% elapsed."""
    if not window:
        return None
    elapsed = window - (reset - now)
    if not window * 0.05 <= elapsed <= window:
        return None
    return pct * window / elapsed


def pct_color(pct):
    return RED if pct >= 80 else YELLOW if pct >= 50 else GREEN


def limit_rows(limits, now, width=36, labels=LABELS):
    keys = [k for k in labels if k in limits] + sorted(k for k in limits if k not in labels)
    rows = []
    for k in keys:
        v = limits[k]
        if not isinstance(v, dict) or v.get("used_percentage") is None:
            continue
        pct = float(v["used_percentage"])
        fill = round(min(pct, 100) / 100 * width)
        label = labels.get(k, k.replace("_", " ").capitalize())
        tail = ""
        try:
            reset = float(v["resets_at"])
            pace = projected(pct, reset, now, window_secs(k))
            if pace is not None:
                tail = f"{pct_color(pace)}→ {pace:.0f}% at reset{RESET}  "
            tail += f"{DIM}resets in {fmt_duration(reset - now)} · {datetime.fromtimestamp(reset):%a %H:%M}{RESET}"
        except (KeyError, TypeError, ValueError):
            pass
        rows.append(f"  {label:<14} {pct_color(pct)}{'█' * fill}{DIM}{'░' * (width - fill)}{RESET} {pct:5.1f}%  {tail}")
    return rows


def cost_usd(model, u):
    """API-equivalent dollars for one response's usage; 0 for an unpriced model."""
    for prefix, inp, out, read in PRICES:
        if model.startswith(prefix):
            break
    else:
        return 0.0
    w1h = (u.get("cache_creation") or {}).get("ephemeral_1h_input_tokens") or 0
    w5m = (u.get("cache_creation_input_tokens") or 0) - w1h
    fast = 2 if u.get("speed") == "fast" else 1
    return fast * ((u.get("input_tokens") or 0) * inp + (u.get("output_tokens") or 0) * out
                   + w5m * inp * 1.25 + w1h * inp * 2 + (u.get("cache_read_input_tokens") or 0) * read) / 1e6


def split_cwd(cwd):
    """Return (repo, worktree); worktree is "" outside a worktree. `jordan/NES-1234-x` branches land as dir names."""
    if not isinstance(cwd, str) or not cwd:
        return "?", ""
    parts = re.split(r"/\.(?:claude/)?worktrees/", cwd, maxsplit=1)
    return Path(parts[0]).name, parts[1].split("/")[0] if len(parts) > 1 else ""


def project_name(cwd):
    return split_cwd(cwd)[0]


def count_lines(result):
    """Return (added, removed) from an Edit/Write tool result."""
    patch = result.get("structuredPatch")
    if isinstance(patch, list) and patch:
        diff = [ln for h in patch if isinstance(h, dict) for ln in h.get("lines") or [] if isinstance(ln, str)]
        return sum(ln.startswith("+") for ln in diff), sum(ln.startswith("-") for ln in diff)
    if result.get("type") == "create" and isinstance(result.get("content"), str):
        return result["content"].count("\n") + 1, 0
    return 0, 0


def scan_file(path):
    """Return ([Usage], [Lines], [Skill], [Tool], [Prompt], [limits]) for one Claude Code transcript."""
    usage, lines, skills, tools, prompts = [], [], [], [], []
    subagent = "subagents" in Path(path).parts
    with open(path, errors="replace") as f:
        for raw in f:
            if not any(s in raw for s in ('"usage"', '"structuredPatch"', "<command-name>", '"role":"user","content":"')):
                continue
            try:
                e = json.loads(raw)
                ts = datetime.fromisoformat(e["timestamp"].replace("Z", "+00:00")).astimezone()
            except (ValueError, TypeError, KeyError, AttributeError):
                continue
            project, worktree = split_cwd(e.get("cwd"))
            msg = e.get("message") if isinstance(e.get("message"), dict) else {}
            model, u, content = msg.get("model") or "", msg.get("usage"), msg.get("content")
            if isinstance(u, dict) and model.startswith("claude-"):
                written = (u.get("input_tokens") or 0) + (u.get("cache_creation_input_tokens") or 0)
                output = u.get("output_tokens") or 0
                thinking = (u.get("output_tokens_details") or {}).get("thinking_tokens") or 0
                usage.append(Usage(f"{msg.get('id')}:{e.get('requestId')}", ts.timestamp(), ts.date(), ts.weekday(), ts.hour,
                                   model.split("-")[1], model, written + output, output, thinking, cost_usd(model, u), written,
                                   u.get("cache_read_input_tokens") or 0, e.get("sessionId"), project, worktree, subagent, "claude"))
            if isinstance(content, list):
                for b in content:
                    if not isinstance(b, dict) or b.get("type") != "tool_use":
                        continue
                    tools.append(Tool(b.get("id"), ts.date(), str(b.get("name"))))
                    if b.get("name") == "Skill" and isinstance(b.get("input"), dict) and b["input"].get("skill"):
                        skills.append(Skill(b.get("id"), ts.date(), str(b["input"]["skill"]), False))
            elif isinstance(content, str) and msg.get("role") == "user":
                if m := COMMAND_RE.search(content):
                    skills.append(Skill(e.get("uuid"), ts.date(), m.group(1), True))
                elif not content.startswith("<") and not e.get("isSidechain"):
                    prompts.append(Prompt(e.get("uuid"), ts.timestamp(), e.get("sessionId"), " ".join(content.split())[:200]))
            if isinstance(e.get("toolUseResult"), dict):
                added, removed = count_lines(e["toolUseResult"])
                if added or removed:
                    lines.append(Lines(e.get("uuid"), ts.date(), project, added, removed))
    return usage, lines, skills, tools, prompts, []


def _stamp(iso):
    return datetime.fromisoformat(iso.replace("Z", "+00:00")).astimezone()


def scan_codex(path):
    """Codex rollout: token_count events, whose model comes from the preceding turn_context."""
    usage, limits = [], []
    session, cwd, model = Path(path).stem, "", ""
    with open(path, errors="replace") as f:
        for raw in f:
            if not any(s in raw for s in ('"token_count"', '"turn_context"', '"session_meta"')):
                continue
            try:
                e = json.loads(raw)
                p = e.get("payload") or {}
                ts = _stamp(e["timestamp"])
            except (ValueError, TypeError, KeyError, AttributeError):
                continue
            session, cwd, model = p.get("session_id") or session, p.get("cwd") or cwd, p.get("model") or model
            if isinstance(p.get("rate_limits"), dict):
                limits.append((ts.timestamp(), p["rate_limits"]))
            u = (p.get("info") or {}).get("last_token_usage") if isinstance(p.get("info"), dict) else None
            if not isinstance(u, dict):
                continue
            # Codex counts cached tokens inside input_tokens; Claude reports them separately.
            cached = u.get("cached_input_tokens") or 0
            fresh = max(0, (u.get("input_tokens") or 0) - cached) + (u.get("cache_write_input_tokens") or 0)
            output = u.get("output_tokens") or 0
            if not fresh + output:
                continue
            usage.append(Usage(f"codex:{session}:{e['timestamp']}", ts.timestamp(), ts.date(), ts.weekday(), ts.hour,
                               "codex", model or "unknown", fresh + output, output, u.get("reasoning_output_tokens") or 0, 0.0,
                               fresh, cached, f"codex:{session}", *split_cwd(cwd), False, "codex"))
    return usage, [], [], [], [], limits


def scan_opencode(path):
    """One opencode assistant message. The mirrored step-finish part file repeats these numbers — ignore it."""
    try:
        e = json.loads(Path(path).read_text())
        ts = datetime.fromtimestamp((e["time"]["created"]) / 1000).astimezone()
    except (OSError, ValueError, TypeError, KeyError):
        return [], [], [], [], [], []
    t = e.get("tokens")
    if e.get("role") != "assistant" or not isinstance(t, dict):
        return [], [], [], [], [], []
    cache = t.get("cache") or {}
    fresh = (t.get("input") or 0) + (cache.get("write") or 0)
    output = t.get("output") or 0
    if not fresh + output:
        return [], [], [], [], [], []
    cost = cost_usd(e.get("modelID") or "", {"input_tokens": t.get("input"), "output_tokens": output,
                                             "cache_creation_input_tokens": cache.get("write"),
                                             "cache_read_input_tokens": cache.get("read")})
    return [Usage(f"opencode:{e.get('id')}", ts.timestamp(), ts.date(), ts.weekday(), ts.hour, "opencode",
                  e.get("modelID") or "unknown", fresh + output, output, t.get("reasoning") or 0, cost, fresh, cache.get("read") or 0,
                  f"opencode:{e.get('sessionID')}", "opencode", "", False, "opencode")], [], [], [], [], []


def scan_cursor(path):
    """cursor-agent SDK run store. immutable=1 skips the WAL, so a live run's newest turn may be missing."""
    try:
        con = sqlite3.connect(f"file:{path}?immutable=1", uri=True)
        rows = con.execute("SELECT run_id, usage_json, created_at, agent_id, model FROM runs WHERE usage_json IS NOT NULL").fetchall()
        workspaces = dict(con.execute("SELECT agent_id, workspace_ref FROM agents"))
        con.close()
    except sqlite3.Error:
        return [], [], [], [], [], []
    usage = []
    for run_id, raw, created, agent, model in rows:
        try:
            u = json.loads(raw)
            ts = _stamp(created)
        except (ValueError, TypeError, AttributeError):
            continue
        fresh = (u.get("inputTokens") or 0) + (u.get("cacheWriteTokens") or 0)
        output = u.get("outputTokens") or 0
        if not fresh + output:
            continue
        usage.append(Usage(f"cursor:{run_id}", ts.timestamp(), ts.date(), ts.weekday(), ts.hour, "cursor",
                           model or "unknown", fresh + output, output, u.get("reasoningTokens") or 0, 0.0, fresh,
                           u.get("cacheReadTokens") or 0, f"cursor:{agent}", *split_cwd(workspaces.get(agent)),
                           False, "cursor"))
    return usage, [], [], [], [], []


SOURCES = (
    ("claude", PROJECTS, "**/*.jsonl", scan_file),
    ("codex", Path.home() / ".codex", "**/rollout-*.jsonl", scan_codex),
    ("opencode", Path.home() / ".local/share/opencode/storage/message", "**/msg_*.json", scan_opencode),
    ("cursor", Path.home() / ".cursor/projects", "*/sdk-agent-store/*/index.db", scan_cursor),
)


@lru_cache(maxsize=None)
def is_skill(name):
    """Typed slash commands include built-ins like /clear; keep only plugin, skill and custom commands."""
    home = Path.home() / ".claude"
    return ":" in name or (home / "skills" / name).is_dir() or (home / "commands" / f"{name}.md").is_file()


_scanned = {}


def aggregate(root, today, days=DAYS, sources=None):
    cutoff = time.time() - (days + 1) * 86400
    usage, lines, skills, tools, prompts = {}, {}, {}, {}, {}
    codex_limits = (None, None)
    timing, last_seen = [], {}
    for name, src_root, pattern, scanner in sources or (("claude", root, "**/*.jsonl", scan_file),):
        started, seen, parsed = time.time(), 0, 0
        for p in src_root.glob(pattern):
            try:
                st = p.stat()
                # Tracked before the cutoff test, so a harness unused in this range can still say when it last ran.
                last_seen[name] = max(last_seen.get(name, 0), st.st_mtime)
                if st.st_mtime < cutoff:
                    continue
                sig = (st.st_mtime, st.st_size)
                seen += 1
                if p not in _scanned or _scanned[p][0] != sig:
                    _scanned[p] = (sig, scanner(p))
                    parsed += 1
            except OSError:
                continue
            file_usage, file_lines, file_skills, file_tools, file_prompts, file_limits = _scanned[p][1]
            # A streamed reply repeats its usage on every content-block line.
            for r in file_usage:
                if r.key not in usage or r.tokens > usage[r.key].tokens:
                    usage[r.key] = r
            lines.update((r.key, r) for r in file_lines)
            skills.update((r.key, r) for r in file_skills)
            tools.update((r.key, r) for r in file_tools)
            prompts.update((r.key, r) for r in file_prompts)
            for ts, lim in file_limits:
                if codex_limits[1] is None or ts > codex_limits[1]:
                    codex_limits = (lim, ts)
        timing.append((name, time.time() - started, seen, parsed))

    start = today - timedelta(days=days - 1)

    def in_range(day):
        return 0 <= (day - start).days < days

    per_day = [{"tokens": defaultdict(int), "cost": defaultdict(float), "lines": defaultdict(int),
                "sessions": set(), "input": 0, "cache_read": 0} for _ in range(days)]
    hours = [[0] * 24 for _ in range(7)]
    projects = defaultdict(lambda: [0, 0.0, 0])
    models = defaultdict(lambda: {"tokens": [0, 0], "cost": 0.0, "output": 0, "thinking": 0})
    subagent = [0, 0.0]
    sessions = {}
    agents = defaultdict(lambda: {"tokens": [0, 0], "cost": 0.0, "sessions": set()})
    for r in usage.values():
        if not in_range(r.day):
            continue
        i = (r.day - start).days
        a = agents[r.tool]
        a["tokens"][1] += r.tokens
        a["cost"] += r.cost
        if i >= days - 7:
            a["tokens"][0] += r.tokens
        if r.session:
            a["sessions"].add(r.session)
        d = per_day[i]
        d["tokens"][r.fam] += r.tokens
        d["cost"][r.fam] += r.cost
        d["input"] += r.input
        d["cache_read"] += r.cache_read
        if r.session:
            d["sessions"].add(r.session)
            s = sessions.setdefault(r.session, {"cost": 0.0, "tokens": 0, "start": r.ts, "end": r.ts,
                                                "project": r.project, "worktree": r.worktree, "prompt": None,
                                                "prompt_ts": None, "tool": r.tool})
            s["cost"] += r.cost
            s["tokens"] += r.tokens
            s["start"], s["end"] = min(s["start"], r.ts), max(s["end"], r.ts)
            if not r.subagent:
                s["project"], s["worktree"] = r.project, r.worktree
        hours[r.weekday][r.hour] += 1
        projects[r.project][0] += r.tokens
        projects[r.project][1] += r.cost
        m = models[(r.tool, r.model)]
        m["tokens"][1] += r.tokens
        if i >= days - 7:
            m["tokens"][0] += r.tokens
        m["cost"] += r.cost
        m["output"] += r.output
        m["thinking"] += r.thinking
        if r.subagent:
            subagent[0] += r.tokens
            subagent[1] += r.cost
    for r in prompts.values():
        s = sessions.get(r.session)
        if s is not None and (s["prompt_ts"] is None or r.ts < s["prompt_ts"]):
            s["prompt"], s["prompt_ts"] = r.text, r.ts
    for r in lines.values():
        if in_range(r.day):
            per_day[(r.day - start).days]["lines"]["added"] += r.added
            per_day[(r.day - start).days]["lines"]["removed"] += r.removed
            projects[r.project][2] += r.added + r.removed
    skill_counts = Counter()
    for r in skills.values():
        if in_range(r.day) and (not r.typed or is_skill(r.name)):
            plugin, _, name = r.name.rpartition(":")
            skill_counts[name if plugin == name else r.name] += 1
    return {"per_day": per_day, "hours": hours, "projects": dict(projects), "skills": skill_counts,
            "agents": dict(agents), "codex_limits": codex_limits, "timing": timing, "models": dict(models),
            "last_seen": last_seen,
            "tools": Counter(r.name for r in tools.values() if in_range(r.day)),
            "subagent": subagent, "sessions": sessions}


def chart_buckets(per_day):
    """Fold days into weeks past 90 days, so a year still fits on one screen. Returns (buckets, days per bucket)."""
    size = 1 if len(per_day) <= 90 else 7
    if size == 1:
        return per_day, size
    buckets = []
    for i in range(0, len(per_day), size):
        merged = {"tokens": defaultdict(int), "cost": defaultdict(float), "lines": defaultdict(int),
                  "sessions": set(), "input": 0, "cache_read": 0}
        for d in per_day[i:i + size]:
            for metric in ("tokens", "cost", "lines"):
                for k, v in d[metric].items():
                    merged[metric][k] += v
            merged["sessions"] |= d["sessions"]
            merged["input"] += d["input"]
            merged["cache_read"] += d["cache_read"]
        buckets.append(merged)
    return buckets, size


def series_totals(per_day, metric):
    """Return {series: [last 7 days, whole range]} for one metric."""
    totals = defaultdict(lambda: [0, 0])
    for i, day in enumerate(per_day):
        for name, v in day[metric].items():
            totals[name][1] += v
            if i >= len(per_day) - 7:
                totals[name][0] += v
    return dict(totals)


def cache_hit(days):
    read = sum(d["cache_read"] for d in days)
    total = read + sum(d["input"] for d in days)
    return f"{read / total:.0%}" if total else "–"


def column_chart(series, order, height=8, recent=7, gap=" ", fmt=fmt_tokens, top=None):
    """Stack each day's series bottom→top in `order`; days before the last `recent` render faint. `top` fixes the scale."""
    totals = [sum(d.values()) for d in series]
    peak = top or max(totals, default=0)
    scale = height * 8 / (peak or 1)
    rows = []
    for r in range(height - 1, -1, -1):
        cells = ""
        for i, day in enumerate(series):
            fill = max(0, min(8, round(totals[i] * scale) - r * 8))
            color, stacked = "", 0
            # One colour per terminal cell: the series at the top of this cell's fill.
            for name in order:
                stacked += day.get(name, 0) * scale
                if fill and stacked >= r * 8 + fill - 0.5:
                    color = series_color(name, faint=i < len(series) - recent)
                    break
            cells += f"{color}{BLOCKS[fill]}{RESET}{gap}"
        axis = fmt(peak) if r == height - 1 else "0" if r == 0 else ""
        rows.append(f"  {axis:>6} ┤{cells}")
    return rows


def chips(items, active, col):
    """Render a row of selectable labels; returns (text, [(start col, end col, value)]) in 1-based columns."""
    parts, spans = [], []
    for value, label in items:
        parts.append(f"{MAGENTA}{BOLD}{label}{RESET}" if value == active else f"{DIM}{label}{RESET}")
        spans.append((col, col + len(label) - 1, value))
        col += len(label) + 2
    return "  ".join(parts), spans


def bar(value, top, width, color):
    fill = round(value / (top or 1) * width)
    return f"{color}{'█' * fill}{RESET}{' ' * (width - fill)}"


def empty(text):
    return [f"  {DIM}{text}{RESET}"]


def codex_limit_rows(data, now):
    """Codex's own windows, normalised onto the Claude keys. Dropped once their reset has passed (stale window)."""
    limits, _ = data["codex_limits"]
    if not isinstance(limits, dict):
        return []
    norm = {}
    for src in (limits.get("primary"), limits.get("secondary")):
        if isinstance(src, dict) and src.get("used_percent") is not None and (src.get("resets_at") or 0) > now:
            norm["five_hour" if (src.get("window_minutes") or 0) <= 600 else "seven_day"] = {
                "used_percentage": src["used_percent"], "resets_at": src["resets_at"]}
    return limit_rows(norm, now, labels={"five_hour": "Codex (5h)", "seven_day": "Codex (7d)"})


def agents_panel(data, days):
    agents = data["agents"]
    if not agents:
        return empty(f"No agent activity in the last {days} days.")
    width = 26
    top = max(a["tokens"][1] for a in agents.values())
    rows = [f"  {'':<9} {'':<{width}} {DIM}{'7d':>7} {f'{days}d':>7} {'cost':>11} {'sessions':>9}{RESET}"]
    for tool, a in sorted(agents.items(), key=lambda kv: -kv[1]["tokens"][1]):
        cost = fmt_cost(a["cost"]) if a["cost"] else "tokens only"
        rows.append(f"  {series_color('opus' if tool == 'claude' else tool)}{tool.capitalize():<9}{RESET}"
                    f" {bar(a['tokens'][1], top, width, series_color('opus' if tool == 'claude' else tool))}"
                    f" {fmt_tokens(a['tokens'][0]):>7} {fmt_tokens(a['tokens'][1]):>7} {cost:>11} {len(a['sessions']):>9}")
    for tool, mtime in sorted(data["last_seen"].items(), key=lambda kv: -kv[1]):
        if tool not in agents:
            rows.append(f"  {series_color(tool, True)}{tool.capitalize():<9}{RESET} {DIM}{'':<{width}}"
                        f" no activity in this range — last used {datetime.fromtimestamp(mtime):%b %d} (press a for all time){RESET}")
    notes = {"codex": "codex: interactive sessions only — headless `codex exec` runs log no usage",
             "cursor": "cursor: cursor-agent SDK runs only — the IDE keeps usage server-side"}
    return rows + [f"  {DIM}{notes[t]}{RESET}" for t in ("codex", "cursor") if t in agents]


def models_panel(data, days, limit=12):
    models = data["models"]
    if not models:
        return empty(f"No model usage in the last {days} days.")
    width = 22
    ranked = sorted(models.items(), key=lambda kv: -kv[1]["tokens"][1])[:limit]
    top = ranked[0][1]["tokens"][1]
    rows = [f"  {'harness':<9} {'model':<20} {'':<{width}} {DIM}{'7d':>7} {f'{days}d':>7} {'cost':>8} {'think':>6}{RESET}"]
    for (tool, model), m in ranked:
        wk, mo = m["tokens"]
        fill, wfill = round(mo / top * width), round(wk / top * width)
        colour = series_color(tool if tool != "claude" else model.split("-")[1] if "-" in model else tool)
        b = f"{colour}{'█' * wfill}{series_color(tool, True)}{'█' * (fill - wfill)}{RESET}{' ' * (width - fill)}"
        think = f"{m['thinking'] / m['output']:.0%}" if m["output"] else "–"
        cost = fmt_cost(m["cost"]) if m["cost"] else "–"
        rows.append(f"  {colour}{tool[:9]:<9}{RESET} {model.removeprefix('claude-')[:20]:<20} {b}"
                    f" {fmt_tokens(wk):>7} {fmt_tokens(mo):>7} {cost:>8} {think:>6}")
    rows.append(f"  {DIM}think = share of output tokens spent thinking · cost only where the model is priced{RESET}")
    return rows


def sessions_panel(data, days, limit=4):
    # Top few per harness, not a global top N: Claude's sessions dwarf the others and would fill the panel.
    per_harness = defaultdict(list)
    for s in sorted(data["sessions"].values(), key=lambda s: -s["tokens"]):
        if len(per_harness[s["tool"]]) < limit:
            per_harness[s["tool"]].append(s)
    ranked = sorted((s for group in per_harness.values() for s in group), key=lambda s: -s["tokens"])
    if not ranked:
        return empty(f"No sessions in the last {days} days.")
    rows = [f"  {DIM}{'harness':<9} {'tokens':>7} {'cost':>8}  {'started':<12}  {'length':>6}  {'project':<10}  {'worktree':<22}  first prompt{RESET}"]
    for s in ranked:
        rows.append(f"  {series_color(s['tool'])}{s['tool'][:9]:<9}{RESET} {fmt_tokens(s['tokens']):>7} {fmt_cost(s['cost']) if s['cost'] else '–':>8}"
                    f"  {datetime.fromtimestamp(s['start']):%b %d %H:%M}  {fmt_duration(s['end'] - s['start']):>6}"
                    f"  {s['project'][:10]:<10}  {(s['worktree'] or '—')[:22]:<22}  {DIM}{(s['prompt'] or '–')[:36]}{RESET}")
    return rows


def counts_panel(counts, what, days, limit=12):
    top = counts.most_common(limit)
    if not top:
        return empty(f"No {what} used in the last {days} days.")
    return [f"  {name[:34]:<34} {bar(n, top[0][1], 30, MAGENTA)} {n:>6}" for name, n in top]


def tools_panel(data, days):
    tokens, cost = data["subagent"]
    total = sum(sum(d["tokens"].values()) for d in data["per_day"])
    share = f"{tokens / total:.0%}" if total else "–"
    return [f"  {DIM}subagents: {share} of tokens · {fmt_cost(cost)}{RESET}"] + counts_panel(data["tools"], "tools", days, limit=11)


def projects_panel(data, days, limit=10):
    ranked = sorted(data["projects"].items(), key=lambda kv: -kv[1][1])[:limit]
    if not ranked:
        return empty(f"No projects in the last {days} days.")
    top = ranked[0][1][1]
    rows = [f"  {'':<24} {'':<24} {DIM}{'tokens':>7} {'cost':>8} {'lines':>7}{RESET}"]
    for name, (tok, cost, changed) in ranked:
        rows.append(f"  {name[:24]:<24} {bar(cost, top, 24, MAGENTA)} {fmt_tokens(tok):>7} {fmt_cost(cost):>8} {fmt_tokens(changed):>7}")
    return rows


def hours_panel(data, days):
    hours = data["hours"]
    top = max(max(row) for row in hours)
    if not top:
        return empty(f"No activity in the last {days} days.")
    rows = [f"      {DIM}" + "".join(f"{h:<12}" for h in (0, 6, 12, 18)) + RESET]
    for wd, name in enumerate(WEEKDAYS):
        cells = "".join(SHADES[min(4, -(-n * 4 // top))] * 2 for n in hours[wd])
        rows.append(f"  {DIM}{name}{RESET} {MAGENTA}{cells}{RESET}")
    wd, h = max(((wd, h) for wd in range(7) for h in range(24)), key=lambda x: hours[x[0]][x[1]])
    rows.append(f"  {DIM}busiest: {WEEKDAYS[wd]} {h:02d}:00 · responses per hour slot{RESET}")
    return rows


def speed_panel(data, days):
    """Where the last load's time went. A file is only re-parsed when its size or mtime changed."""
    timing = data.get("timing") or []
    total = sum(t[1] for t in timing)
    rows = [f"  {'source':<12} {'':<20} {DIM}{'time':>7} {'files':>7} {'parsed':>7}{RESET}"]
    for name, secs, seen, parsed in sorted(timing, key=lambda t: -t[1]):
        rows.append(f"  {name[:12]:<12} {bar(secs, total, 20, MAGENTA)} {secs:6.2f}s {seen:>7} {parsed:>7}")
    rows.append(f"  {BOLD}{'total':<12}{RESET} {'':<20} {BOLD}{total:6.2f}s{RESET}")
    loads = data.get("loads") or []
    recent = " ".join(f"{secs:.2f}s" for _, secs, _ in loads[-6:])
    rows += ["", f"  {DIM}last loads ({days}d): {recent}{RESET}",
             f"  {DIM}first load parses everything; later ones re-parse only changed files · ai-stats --bench for cold vs warm{RESET}"]
    return rows


def limits_panel(data, days, cols=60, span=7 * 86400):
    if not data["history"]:
        return empty("No limit history yet: the statusline records a sample every 5 minutes.")
    buckets = [{} for _ in range(cols)]
    for t, s, w in data["history"]:
        b = buckets[min(cols - 1, int((t - (data["now"] - span)) / span * cols))]
        b["session"], b["week"] = max(b.get("session", 0), s), max(b.get("week", 0), w)
    pct = lambda v: f"{v:.0f}%"  # noqa: E731
    rows = [f"  {series_color('week')}Week %{RESET}"]
    rows += column_chart([{"week": b.get("week", 0)} for b in buckets], ["week"], height=4, recent=cols, gap="", fmt=pct, top=100)
    rows += [f"  {series_color('session')}Session %{RESET}"]
    rows += column_chart([{"session": b.get("session", 0)} for b in buckets], ["session"], height=3, recent=cols, gap="", fmt=pct, top=100)
    rows.append(f"          {DIM}7 days ago{'now':>{cols - 10}}{RESET}")
    return rows


_load_history = []


def load(days):
    today, now = datetime.now().date(), time.time()
    data = aggregate(PROJECTS, today, days, SOURCES)
    _load_history.append((days, time.time() - now, sum(t[3] for t in data["timing"])))
    del _load_history[:-8]
    return {**data, "limits": load_limits(), "history": load_history(now), "loads": list(_load_history),
            "today": today, "now": now}


def render(data, sel, metric="tokens", panel="models"):
    now = time.time()
    per_day, today = data["per_day"], data["today"]
    days = len(per_day)
    start = today - timedelta(days=days - 1)
    limits, mtime = data["limits"]

    head = f" {BOLD}AI usage{RESET}  "
    range_text, HITS["range"] = chips(RANGE_CHIPS, days, len(" AI usage  ") + 1)
    out = [f"{head}{range_text}  {DIM}{datetime.now():%a %b %d %H:%M} · click or keys · ←/→ move · c chart · r refresh · q quit{RESET}", ""]
    stamp = f"  {DIM}as of {fmt_duration(now - mtime)} ago{RESET}" if mtime is not None else ""
    out.append(f" {MAGENTA}{BOLD}Plan limits{RESET}{stamp}")
    out += limit_rows(limits, now) or empty("No data yet: limits are captured when a Claude Code session renders its statusline.")
    codex_rows = codex_limit_rows(data, now)
    out += codex_rows
    missing = [t for t in ("codex", "opencode", "cursor") if t in data["agents"]]
    if missing:
        absent = [t for t in missing if t != "codex" or not codex_rows]
        if absent:
            out.append(f"  {DIM}{', '.join(absent)}: no live plan limits on disk"
                       f"{' (codex logs them only while a session window is open)' if 'codex' in absent else ''}{RESET}")

    tok = [sum(d["tokens"].values()) for d in per_day]
    cost = sum(sum(d["cost"].values()) for d in per_day)
    sessions = len(set().union(*(d["sessions"] for d in per_day)))
    added = sum(d["lines"]["added"] for d in per_day)
    removed = sum(d["lines"]["removed"] for d in per_day)
    out += ["", f" {MAGENTA}{BOLD}{days}d{RESET}  {BOLD}{fmt_tokens(sum(tok))}{RESET} tokens {DIM}(week {fmt_tokens(sum(tok[-7:]))}){RESET}"
                f" · {BOLD}{fmt_cost(cost)}{RESET} · {BOLD}{sessions}{RESET} sessions · {BOLD}{cache_hit(per_day)}{RESET} cache hit"
                f" · {GREEN}+{fmt_tokens(added)}{RESET} {RED}−{fmt_tokens(removed)}{RESET} lines"]

    buckets, size = chart_buckets(per_day)
    sel = min(sel, len(buckets) - 1)
    title = {"tokens": "Tokens excl. cache reads", "cost": "API-equivalent cost", "lines": "Lines added / removed"}[metric]
    grain = f" · {DIM}weekly{RESET}" if size > 1 else ""
    out.append(f" {MAGENTA}{BOLD}{title}{RESET}{grain}  {DIM}faint = before last 7d · c to switch{RESET}")
    totals = series_totals(per_day, metric)
    order = ["removed", "added"] if metric == "lines" else sorted(totals, key=lambda s: -totals[s][1])
    # 90 two-char columns would overflow a normal terminal.
    gap = " " if len(buckets) <= 45 else ""
    cell = 1 + len(gap)
    chart = column_chart([b[metric] for b in buckets], order, recent=7 // size or 1, gap=gap,
                         fmt=fmt_cost if metric == "cost" else fmt_tokens)
    # Chart rows are "  <6-wide axis> ┤" before the first cell, so cells start at column 11.
    HITS["chart"] = (len(out) + 1, len(out) + len(chart), 11, cell, len(buckets))
    out += chart
    axis = ["─"] * (len(buckets) * cell)
    axis[sel * cell] = f"{YELLOW}▲{RESET}"
    out.append(f"         └{''.join(axis)}")
    left, right = f"{start:%b %d}", "today"
    out.append(f"          {DIM}{left}{right:>{len(buckets) * cell - len(left)}}{RESET}")

    d = buckets[sel]
    sel_start = start + timedelta(days=sel * size)
    sel_label = f"{sel_start:%a %b %d}" if size == 1 else f"week of {sel_start:%b %d}"
    breakdown = " · ".join(f"{series_color(fam)}{fam.capitalize()}{RESET} {fmt_tokens(t)}"
                           for fam, t in sorted(d["tokens"].items(), key=lambda kv: -kv[1]))
    out.append(f"  {YELLOW}▲{RESET} {BOLD}{sel_label}{RESET}  {fmt_tokens(sum(d['tokens'].values()))} · {fmt_cost(sum(d['cost'].values()))}"
               f" · {len(d['sessions'])} sessions · {cache_hit([d])} cache · {GREEN}+{d['lines']['added']}{RESET} {RED}−{d['lines']['removed']}{RESET}"
               f"  {breakdown or DIM + 'no usage' + RESET}")

    tabs, spans = chips([(p, p.capitalize()) for p in PANELS], panel, 2)
    HITS["panel"] = [(len(out) + 2, x0, x1, value) for x0, x1, value in spans]
    out += ["", f" {tabs}"]
    out += {"models": models_panel, "agents": agents_panel, "sessions": sessions_panel, "skills": lambda dt, n: counts_panel(dt["skills"], "skills", n),
            "tools": tools_panel, "projects": projects_panel, "hours": hours_panel, "limits": limits_panel,
            "speed": speed_panel}[panel](data, days)
    return out


def summary(data):
    """The --json payload: current limits with pace, plus today's and the last 7 days' tokens and cost."""
    now = data["now"]
    limits, mtime = data["limits"]
    out = {}
    for k, v in limits.items():
        if not isinstance(v, dict) or v.get("used_percentage") is None:
            continue
        pct = float(v["used_percentage"])
        try:
            pace = projected(pct, float(v["resets_at"]), now, window_secs(k))
        except (KeyError, TypeError, ValueError):
            pace = None
        out[k] = {"used_percentage": pct, "resets_at": v.get("resets_at"),
                  "projected_percentage": None if pace is None else round(pace, 1)}

    def totals(days):
        return {"tokens": sum(sum(d["tokens"].values()) for d in days),
                "cost_usd": round(sum(sum(d["cost"].values()) for d in days), 2)}

    return {"limits": out, "limits_age_secs": None if mtime is None else round(now - mtime),
            "today": totals(data["per_day"][-1:]), "week": totals(data["per_day"][-7:])}


def bench():
    """Timing breakdown: cold (no file cache) vs warm per range, then per source at 30 days."""
    today = datetime.now().date()

    def run(days, sources):
        _scanned.clear()
        t0 = time.time()
        data = aggregate(PROJECTS, today, days, sources)
        cold, files = time.time() - t0, len(_scanned)
        t0 = time.time()
        aggregate(PROJECTS, today, days, sources)
        return cold, time.time() - t0, files, sum(sum(d["tokens"].values()) for d in data["per_day"])

    print(f" {'range':>6} {'cold':>7} {'warm':>7} {'files':>7} {'tokens':>8}")
    for days in (1, 7, 30, 90, 365):
        cold, warm, files, tokens = run(days, SOURCES)
        print(f" {f'{days}d':>6} {cold:6.2f}s {warm:6.2f}s {files:>7} {fmt_tokens(tokens):>8}")
    print(f"\n per source (30d)\n {'source':>10} {'cold':>7} {'warm':>7} {'files':>7} {'tokens':>8}")
    for source in SOURCES:
        cold, warm, files, tokens = run(30, (source,))
        print(f" {source[0]:>10} {cold:6.2f}s {warm:6.2f}s {files:>7} {fmt_tokens(tokens):>8}")


def click_action(row, col):
    """Map a click to ("panel"|"range"|"sel", value), or None when it lands on nothing clickable."""
    for hit_row, x0, x1, value in HITS["panel"]:
        if row == hit_row and x0 <= col <= x1:
            return "panel", value
    for x0, x1, value in HITS["range"]:
        if row == 1 and x0 <= col <= x1:
            return "range", value
    if HITS["chart"]:
        top, bottom, x0, cell, count = HITS["chart"]
        if top <= row <= bottom and x0 <= col < x0 + count * cell:
            return "sel", (col - x0) // cell
    return None


def main():
    if "--bench" in sys.argv[1:]:
        bench()
        return
    if "--json" in sys.argv[1:]:
        print(json.dumps(summary(load(7))))
        return
    days, metric, panel = DAYS, 0, 0
    if not sys.stdin.isatty() or not sys.stdout.isatty():
        print("\n".join(render(load(days), days - 1)))
        return
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    sys.stdout.write("\033[?1049h\033[?25l\033[2J" + MOUSE_ON)
    try:
        tty.setcbreak(fd)
        sel, data, loaded = days - 1, load(days), time.time()
        while True:
            # Overwrite in place rather than clearing, so holding an arrow key doesn't flicker.
            frame = render(data, sel, METRICS[metric], PANELS[panel])
            sys.stdout.write("\033[H" + "".join(line + "\033[K\n" for line in frame) + "\033[J")
            sys.stdout.flush()
            if not select.select([fd], [], [], max(0, REFRESH_SECS - (time.time() - loaded)))[0]:
                data, loaded = load(days), time.time()
                continue
            key = os.read(fd, 64).decode(errors="ignore")
            if key in ("", "q", "Q"):
                break
            columns = len(chart_buckets(data["per_day"])[0])
            if (m := MOUSE_RE.match(key)) and m.group(4) == "M":
                button, col, row = int(m.group(1)), int(m.group(2)), int(m.group(3))
                if button == 64:
                    sel = max(0, min(sel, columns - 1) - 1)
                elif button == 65:
                    sel = min(columns - 1, sel + 1)
                elif button == 0 and (action := click_action(row, col)):
                    kind, value = action
                    if kind == "panel":
                        panel = PANELS.index(value)
                    elif kind == "sel":
                        sel = value
                    elif value != days:
                        days = value
                        data, loaded = load(days), time.time()
                        sel = len(chart_buckets(data["per_day"])[0]) - 1
                continue
            if key in LEFT:
                sel = max(0, min(sel, columns - 1) - 1)
            elif key in RIGHT:
                sel = min(columns - 1, sel + 1)
            elif key == "c":
                metric = (metric + 1) % len(METRICS)
            elif key == "\t":
                panel = (panel + 1) % len(PANELS)
            elif key in RANGES or key == "r":
                days = RANGES.get(key, days)
                data, loaded = load(days), time.time()
                last = len(chart_buckets(data["per_day"])[0]) - 1
                sel = min(sel, last) if key == "r" else last
    except KeyboardInterrupt:
        pass
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)
        sys.stdout.write(MOUSE_OFF + "\033[?25h\033[?1049l")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
