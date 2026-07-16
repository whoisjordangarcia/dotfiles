#!/usr/bin/env python3
"""Preview and validate Claude Code custom themes.

Claude Code reads ~/.claude/themes/<slug>.json and registers each as
`custom:<slug>`. THE SLUG IS THE FILENAME — the "name" field is only the label
shown in /theme. Select one with /theme, or set "theme": "custom:<slug>" in
settings.{work,personal}.json.

Theme file shape:
    {"name": "...", "base": "dark", "overrides": {"<key>": "<color>", ...}}

The loader is SILENTLY LOSSY: an override whose key isn't a real theme key, or
whose color doesn't parse, is dropped with no error — the theme just renders
wrong. `--check` is the guard against that.

Usage:
    ./theme_preview.py                 # preview every theme in this directory
    ./theme_preview.py foo.json        # preview one theme
    ./theme_preview.py --check         # validate only; non-zero exit on problems

Authoring notes (rules the built-in themes follow — see CLAUDE.md):
  * shimmer keys are the base color BRIGHTENED ADDITIVELY (~+38/channel, clamped),
    not blended toward white.
  * `subtle` is DARKER than `inactive` (built-in dark: 80 vs 153 grey).
  * diff fills want a monotonic chroma hierarchy: Dimmed < normal < Word.
"""

import glob
import json
import os
import re
import sys

# ── loader contract, extracted from the Claude Code binary ───────────────────
# JOe(): the accepted color formats.
COLOR_RE = re.compile(
    r"^#[0-9a-fA-F]{6}$|^#[0-9a-fA-F]{3}$"
    r"|^rgb\(\s?\d{1,3},\s?\d{1,3},\s?\d{1,3}\s?\)$"
    r"|^ansi256\(\d{1,3}\)$|^ansi:"
)
# Wdi: valid `base` values. An unknown base silently falls back to "dark".
BASES = ["dark", "light", "light-daltonized", "dark-daltonized", "light-ansi", "dark-ansi"]
MAX_BYTES = 262144  # mhg: files larger than this are skipped outright

# Vpg: the built-in `dark` theme. Doubles as the authoritative key set — an
# override key absent from here is dropped by the loader.
BASE_DARK = {
    'autoAccept': 'rgb(175,135,255)',
    'autoAcceptShimmer': 'rgb(208,180,255)',
    'skill': 'rgb(175,135,255)',
    'bashBorder': 'rgb(253,93,177)',
    'claude': 'rgb(215,119,87)',
    'claudeShimmer': 'rgb(235,159,127)',
    'claudeBlue_FOR_SYSTEM_SPINNER': 'rgb(147,165,255)',
    'claudeBlueShimmer_FOR_SYSTEM_SPINNER': 'rgb(177,195,255)',
    'permission': 'rgb(177,185,249)',
    'permissionShimmer': 'rgb(207,215,255)',
    'planMode': 'rgb(72,150,140)',
    'ide': 'rgb(71,130,200)',
    'promptBorder': 'rgb(136,136,136)',
    'promptBorderShimmer': 'rgb(166,166,166)',
    'text': 'rgb(255,255,255)',
    'inverseText': 'rgb(0,0,0)',
    'inactive': 'rgb(153,153,153)',
    'inactiveShimmer': 'rgb(193,193,193)',
    'subtle': 'rgb(80,80,80)',
    'suggestion': 'rgb(177,185,249)',
    'remember': 'rgb(177,185,249)',
    'background': 'rgb(0,204,204)',
    'success': 'rgb(78,186,101)',
    'error': 'rgb(255,107,128)',
    'warning': 'rgb(255,193,7)',
    'merged': 'rgb(175,135,255)',
    'warningShimmer': 'rgb(255,223,57)',
    'diffAdded': 'rgb(34,92,43)',
    'diffRemoved': 'rgb(122,41,54)',
    'diffAddedDimmed': 'rgb(71,88,74)',
    'diffRemovedDimmed': 'rgb(105,72,77)',
    'diffAddedWord': 'rgb(56,166,96)',
    'diffRemovedWord': 'rgb(179,89,107)',
    'red_FOR_SUBAGENTS_ONLY': 'rgb(220,38,38)',
    'blue_FOR_SUBAGENTS_ONLY': 'rgb(106,155,204)',
    'green_FOR_SUBAGENTS_ONLY': 'rgb(22,163,74)',
    'yellow_FOR_SUBAGENTS_ONLY': 'rgb(202,138,4)',
    'purple_FOR_SUBAGENTS_ONLY': 'rgb(130,125,189)',
    'orange_FOR_SUBAGENTS_ONLY': 'rgb(217,119,87)',
    'pink_FOR_SUBAGENTS_ONLY': 'rgb(196,102,134)',
    'cyan_FOR_SUBAGENTS_ONLY': 'rgb(8,145,178)',
    'professionalBlue': 'rgb(106,155,204)',
    'chromeYellow': 'rgb(251,188,4)',
    'clawd_body': 'rgb(215,119,87)',
    'clawd_background': 'rgb(0,0,0)',
    'userMessageBackground': 'rgb(55, 55, 55)',
    'userMessageBackgroundHover': 'rgb(70, 70, 70)',
    'composerSidebarBackground': 'rgb(38, 38, 38)',
    'selectionBg': 'rgb(38, 79, 120)',
    'bashMessageBackgroundColor': 'rgb(65, 60, 65)',
    'memoryBackgroundColor': 'rgb(55, 65, 70)',
    'rate_limit_fill': 'rgb(177,185,249)',
    'rate_limit_empty': 'rgb(80,83,112)',
    'fastMode': 'rgb(255,120,20)',
    'fastModeShimmer': 'rgb(255,165,70)',
    'effortUltra': 'rgb(175,135,255)',
    'briefLabelYou': 'rgb(122,180,232)',
    'briefLabelClaude': 'rgb(215,119,87)',
    'rainbow_red': 'rgb(235,95,87)',
    'rainbow_orange': 'rgb(245,139,87)',
    'rainbow_yellow': 'rgb(250,195,95)',
    'rainbow_green': 'rgb(145,200,130)',
    'rainbow_blue': 'rgb(130,170,220)',
    'rainbow_indigo': 'rgb(155,130,200)',
    'rainbow_violet': 'rgb(200,130,180)',
    'rainbow_red_shimmer': 'rgb(250,155,147)',
    'rainbow_orange_shimmer': 'rgb(255,185,137)',
    'rainbow_yellow_shimmer': 'rgb(255,225,155)',
    'rainbow_green_shimmer': 'rgb(185,230,180)',
    'rainbow_blue_shimmer': 'rgb(180,205,240)',
    'rainbow_indigo_shimmer': 'rgb(195,180,230)',
    'rainbow_violet_shimmer': 'rgb(230,180,210)',}

# ── color helpers ────────────────────────────────────────────────────────────
ANSI16 = {
    "black": 0, "red": 1, "green": 2, "yellow": 3, "blue": 4, "magenta": 5,
    "cyan": 6, "white": 7,
}


def to_rgb(v):
    """Resolve any accepted color format to (r,g,b), or None if unrenderable."""
    if v.startswith("#"):
        h = v[1:]
        if len(h) == 3:
            h = "".join(c * 2 for c in h)
        return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
    m = re.match(r"^rgb\(\s?(\d{1,3}),\s?(\d{1,3}),\s?(\d{1,3})\s?\)$", v)
    if m:
        return tuple(int(g) for g in m.groups())
    return None  # ansi:/ansi256() are terminal-defined; no fixed RGB


def bg(v, s):
    c = to_rgb(v)
    return f"\x1b[48;2;{c[0]};{c[1]};{c[2]}m{s}\x1b[0m" if c else s


def fg(v, s):
    c = to_rgb(v)
    return f"\x1b[38;2;{c[0]};{c[1]};{c[2]}m{s}\x1b[0m" if c else s


# ── loader simulation ────────────────────────────────────────────────────────
def load(path):
    """Mirror ghg()/eiu(): returns (theme, problems). Never raises."""
    problems = []
    slug = os.path.basename(path)[:-5]

    if os.path.getsize(path) > MAX_BYTES:
        return None, [f"exceeds 256KB — the loader skips this file entirely"]
    try:
        raw = json.load(open(path))
    except json.JSONDecodeError as e:
        return None, [f"invalid JSON: {e}"]
    if not isinstance(raw, dict):
        return None, ["top level must be an object"]

    base = raw.get("base")
    if base is None:
        problems.append('no "base" — defaults to "dark"')
        base = "dark"
    elif base not in BASES:
        problems.append(f'base {base!r} is not valid — SILENTLY falls back to "dark" '
                        f'(valid: {", ".join(BASES)})')
        base = "dark"
    if base != "dark":
        problems.append(f'base is {base!r}; preview fills unset keys from the built-in '
                        f'"dark" theme, so unset keys may render inaccurately')

    name = raw.get("name")
    if not isinstance(name, str):
        problems.append(f'no "name" string — /theme will label it {slug!r}')
        name = slug

    kept, ov = {}, raw.get("overrides")
    if not isinstance(ov, dict):
        problems.append('no "overrides" object — theme is identical to its base')
        ov = {}
    for k, v in ov.items():
        if k not in BASE_DARK:
            problems.append(f"unknown key {k!r} — DROPPED (typo? not a real theme key)")
        elif not isinstance(v, str) or not COLOR_RE.match(v):
            problems.append(f"{k}: {v!r} is not a valid color — DROPPED")
        else:
            kept[k] = v

    merged = dict(BASE_DARK)
    merged.update(kept)
    return {"slug": slug, "name": name, "base": base, "kept": kept,
            "unset": [k for k in BASE_DARK if k not in kept], "colors": merged}, problems


# ── preview ──────────────────────────────────────────────────────────────────
GROUPS = [
    ("accents", ["claude", "autoAccept", "skill", "planMode", "permission",
                 "bashBorder", "ide", "merged", "effortUltra", "fastMode"]),
    ("status", ["success", "warning", "error", "suggestion", "remember"]),
    ("text", ["text", "inactive", "subtle", "promptBorder", "inverseText"]),
    ("surfaces", ["userMessageBackground", "userMessageBackgroundHover",
                  "composerSidebarBackground", "selectionBg",
                  "bashMessageBackgroundColor", "memoryBackgroundColor"]),
    ("diff", ["diffAddedDimmed", "diffAdded", "diffAddedWord",
              "diffRemovedDimmed", "diffRemoved", "diffRemovedWord"]),
    ("subagents", [f"{c}_FOR_SUBAGENTS_ONLY" for c in
                   ["red", "blue", "green", "yellow", "purple", "orange", "pink", "cyan"]]),
    ("rainbow", [f"rainbow_{c}" for c in
                 ["red", "orange", "yellow", "green", "blue", "indigo", "violet"]]),
]


def preview(t):
    c = t["colors"]
    canvas = c["clawd_background"]
    mark = lambda k: " " if k in t["kept"] else fg(c["subtle"], "·")  # noqa: E731

    print()
    print(f"  {fg(c['claude'], t['name'])}  {fg(c['inactive'], 'custom:' + t['slug'])}"
          f"  {fg(c['subtle'], 'base ' + t['base'])}")
    tally = f"{len(t['kept'])}/{len(BASE_DARK)} keys overridden   (· = inherited from base)"
    print("  " + fg(c["subtle"], tally))
    print()

    for title, keys in GROUPS:
        print(f"  {fg(c['inactive'], title)}")
        for k in keys:
            v = c[k]
            sw = bg(v, "    ") if to_rgb(v) else f"{v:>4}"
            shim = c.get(k + "Shimmer")
            extra = f"  {fg(c['subtle'], '+shimmer')} {bg(shim, '  ')} {fg(c['inactive'], shim)}" if shim else ""
            print(f"    {mark(k)} {sw} {fg(c['inactive'], f'{v:<8}')} {fg(v, k)}{extra}")
        print()

    # A mock of the surfaces these colors actually land on.
    W = 64
    line = lambda s="": print("  " + bg(canvas, s.ljust(W)))  # noqa: E731
    print(f"  {fg(c['inactive'], 'in context')}")
    line()
    line(f"  {fg(c['claude'], '✻')} {fg(c['text'], 'Claude Code')}  {fg(c['inactive'], '~/dev/dotfiles')}")
    line()
    line(f"  {fg(c['autoAccept'], '⏵⏵ accept edits on')}   {fg(c['planMode'], '⏸ plan mode')}")
    line(f"  {fg(c['permission'], '❯ Allow this tool?')}  {fg(c['suggestion'], '(suggestion)')}")
    line(f"  {fg(c['success'], '✔ 12 passed')}  {fg(c['warning'], '⚠ 2 warnings')}  {fg(c['error'], '✘ 1 failed')}")
    line()
    line(f"  {bg(c['diffAdded'], fg(c['text'], '+ added line '))}"
         f"{bg(c['diffAddedWord'], fg(c['text'], 'changed word'))}")
    line(f"  {bg(c['diffRemoved'], fg(c['text'], '- removed line '))}"
         f"{bg(c['diffRemovedWord'], fg(c['text'], 'changed word'))}")
    line()
    line(f"  {bg(c['userMessageBackground'], fg(c['text'], ' a user message '))}"
         f" {bg(c['selectionBg'], fg(c['text'], ' selected '))}")
    line(f"  {fg(c['subtle'], 'subtle')}  {fg(c['inactive'], 'inactive')}  {fg(c['text'], 'text')}"
         f"  {bg(c['text'], fg(c['inverseText'], ' inverseText '))}")
    line()
    print()


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    check_only = "--check" in sys.argv
    if "-h" in sys.argv or "--help" in sys.argv:
        print(__doc__)
        return 0

    here = os.path.dirname(os.path.abspath(__file__))
    paths = args or sorted(glob.glob(os.path.join(here, "*.json")))
    if not paths:
        print(f"no themes found in {here}", file=sys.stderr)
        return 1

    failed = False
    for p in paths:
        t, problems = load(p)
        if problems:
            failed = True
            print(f"\n  {os.path.basename(p)}")
            for msg in problems:
                print(f"    ✗ {msg}")
        elif check_only:
            print(f"  ✓ {os.path.basename(p):32} custom:{t['slug']:24} "
                  f"{len(t['kept'])}/{len(BASE_DARK)} keys")
        if t and not check_only:
            preview(t)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
