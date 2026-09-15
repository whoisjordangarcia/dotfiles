#!/usr/bin/env python3
import importlib.util
import json
import re
import tempfile
from datetime import datetime, timezone
from pathlib import Path

spec = importlib.util.spec_from_file_location("claude_stats", Path(__file__).with_name("claude_stats.py"))
cs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cs)

passed = 0


def check(name, cond):
    global passed
    print(("✓ " if cond else "✗ ") + name)
    if not cond:
        raise SystemExit(1)
    passed += 1


def plain(s):
    return re.sub(r"\033\[[0-9;?]*[A-Za-z]", "", s)


NOON = datetime.now().astimezone().replace(hour=12).astimezone(timezone.utc).isoformat()
CWD = "/src/nest/.worktrees/jordan-feature"


def reply(msg_id, model, tokens, session="s1", content=None, output=0, thinking=0):
    return json.dumps({"requestId": "r-" + msg_id, "timestamp": NOON, "sessionId": session, "cwd": CWD, "message": {
        "id": msg_id, "model": model, "content": content or [],
        "usage": {"input_tokens": tokens, "output_tokens": output, "cache_read_input_tokens": 300,
                  "output_tokens_details": {"thinking_tokens": thinking}}}})


def user(uuid, **fields):
    return json.dumps({"uuid": uuid, "timestamp": NOON, "cwd": CWD, **fields}, separators=(",", ":"))


with tempfile.TemporaryDirectory() as tmp:
    today = datetime.now().date()
    proj = Path(tmp) / "proj"
    proj.mkdir()
    skill_use = [{"type": "tool_use", "id": "t1", "name": "Skill", "input": {"skill": "daily-note"}},
                 {"type": "tool_use", "id": "t2", "name": "Skill", "input": {"skill": "daily-note:daily-note"}}]
    (proj / "a.jsonl").write_text("\n".join([
        reply("m1", "claude-fable-5-1", 100, content=skill_use),
        reply("m1", "claude-fable-5-1", 100, content=skill_use),  # same reply, second content block
        reply("m2", "claude-opus-5", 50, session="s2", output=40, thinking=10,
              content=[{"type": "tool_use", "id": "t3", "name": "Bash", "input": {}}]),
        reply("m3", "<synthetic>", 7),
        user("u0", sessionId="s2", message={"role": "user", "content": "fix the   flaky\ntest"}),
        user("u1", message={"role": "user", "content": "<command-name>/superpowers:brainstorming</command-name>"}),
        user("u2", message={"role": "user", "content": "<command-name>/clear</command-name>"}),
        user("u3", toolUseResult={"structuredPatch": [{"lines": [" keep", "-old", "+new", "+more"]}]}),
        user("u4", toolUseResult={"type": "create", "content": "a\nb\nc", "structuredPatch": []}),
        "not json",
    ]))
    sub = proj / "s1" / "subagents"
    sub.mkdir(parents=True)
    (sub / "agent-x.jsonl").write_text(reply("m4", "claude-sonnet-5", 25))
    data = cs.aggregate(Path(tmp), today)
    day = data["per_day"][-1]
    check("subagent tokens attributed to subagents", data["subagent"][0] == 25)
    check("tool uses counted by name, once per call", data["tools"] == {"Skill": 2, "Bash": 1})
    check("thinking share tracked per model", data["thinking"]["opus"] == [40, 10])
    check("session keeps its first typed prompt, whitespace collapsed", data["sessions"]["s2"]["prompt"] == "fix the flaky test")
    check("session cost sums its replies", data["sessions"]["s2"]["cost"] == cs.cost_usd("claude-opus-5", {
        "input_tokens": 50, "output_tokens": 40, "cache_read_input_tokens": 300}))
    check("streamed reply counted once, cache reads and synthetic messages excluded",
          dict(day["tokens"]) == {"fable": 100, "opus": 90, "sonnet": 25})
    check("model split carries week and range", cs.series_totals(data["per_day"], "tokens")["fable"] == [100, 100])
    check("sessions counted distinct, subagents fold into their session", day["sessions"] == {"s1", "s2"})
    check("cache hit = reads over all input", cs.cache_hit([day]) == f"{900 / 1075:.0%}")
    check("lines from patch and new file", dict(day["lines"]) == {"added": 5, "removed": 1})
    check("skill tool use counted once per call, plugin:same-name merged", data["skills"]["daily-note"] == 2)
    check("typed plugin command counted, built-in ignored",
          data["skills"]["superpowers:brainstorming"] == 1 and "clear" not in data["skills"])
    check("worktrees roll up to their repo", set(data["projects"]) == {"nest"})
    check("activity lands in the noon slot", data["hours"][today.weekday()][12] == 3)
    data.update(limits=({"seven_day": {"used_percentage": 50, "resets_at": 1000 + 3.5 * 86400}}, 990), now=1000, history=[], today=today)
    js = cs.summary(data)
    check("json: week pace projected to reset", js["limits"]["seven_day"]["projected_percentage"] == 100)
    check("json: today and week totals", js["today"] == js["week"] and js["today"]["tokens"] == 215)
    check("json: cache age in seconds", js["limits_age_secs"] == 10)
    for panel in cs.PANELS:
        check(f"panel renders: {panel}", len(cs.render(data, cs.DAYS - 1, "cost", panel)) > 10)
    check("window has one slot per day", len(data["per_day"]) == cs.DAYS)
    check("range length follows the argument", len(cs.aggregate(Path(tmp), today, 90)["per_day"]) == 90)

check("opus input priced at $5/MTok", cs.cost_usd("claude-opus-5", {"input_tokens": 1_000_000}) == 5)
check("fable 5.1 cache reads at $0.25/MTok", cs.cost_usd("claude-fable-5-1", {"cache_read_input_tokens": 1_000_000}) == 0.25)
check("1h cache writes at 2x, 5m at 1.25x", cs.cost_usd("claude-sonnet-5", {
    "cache_creation_input_tokens": 2_000_000, "cache_creation": {"ephemeral_1h_input_tokens": 1_000_000}}) == 2 * 2 + 2 * 1.25)
check("fast mode doubles the price", cs.cost_usd("claude-opus-5", {"output_tokens": 1_000_000, "speed": "fast"}) == 50)
check("unknown model costs nothing", cs.cost_usd("claude-mystery", {"input_tokens": 1}) == 0)

rows = [plain(r) for r in cs.column_chart([{}, {"opus": 4}, {"opus": 8}], ["opus"], height=2, recent=0)]
check("chart top row fills only the max column", rows[0].endswith("┤    █ "))
check("chart bottom row fills half and max", rows[1].endswith("┤  █ █ "))
check("chart survives all-zero input", len(cs.column_chart([{}, {}], [])) == 8)
rows = cs.column_chart([{"opus": 4, "fable": 4}], ["opus", "fable"], height=2, recent=1)
check("stacked column: first series at the bottom", cs.series_color("opus") + "█" in rows[1])
check("stacked column: next series above it", cs.series_color("fable") + "█" in rows[0])
check("days before the recent window are faint",
      cs.series_color("opus", faint=True) in cs.column_chart([{"opus": 1}, {"opus": 1}], ["opus"], recent=1)[-1])

limits = {"seven_day_fable": {"used_percentage": 12}, "seven_day": {"used_percentage": 90},
          "five_hour": {"used_percentage": 40, "resets_at": 4000}}
rows = [plain(r) for r in cs.limit_rows(limits, now=0)]
check("known windows first, extras after", [r.split()[0] for r in rows] == ["Session", "Week", "Seven"])
check("reset countdown rendered", "resets in 1h06m" in rows[0])
check("pace: half used at half-window projects to 100", cs.projected(50, 50, 0, 100) == 100)
check("pace: too early in the window says nothing", cs.projected(50, 99, 0, 100) is None)
check("pace: unknown window says nothing", cs.projected(50, 50, 0, None) is None)
check("pace shown on the session row", "→" in plain(cs.limit_rows({"five_hour": {"used_percentage": 10, "resets_at": 9000}}, 0)[0]))
hist = {"history": [(0, 10, 20), (7 * 86400, 30, 80)], "now": 7 * 86400}
rows = [plain(r) for r in cs.limits_panel(hist, 7, cols=10)]
check("limit history: latest week sample peaks the last column", rows[1].endswith("┤         ▂"))
check("null percentage skipped", cs.limit_rows({"five_hour": {"used_percentage": None}}, 0) == [])

check("duration under a minute", cs.fmt_duration(30) == "<1m")
check("token formatting", cs.fmt_tokens(1_250_000) == "1.2M")

print(f"All {passed} tests passed")
