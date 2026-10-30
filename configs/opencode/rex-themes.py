#!/usr/bin/env python3
"""OpenCode themes from Rex's: rex-<id>.json for each Rex theme, and rex.json pairing the dark and light
themes Rex is set to, so `"theme": {"name": "rex", "mode": "system"}` follows Rex's appearance.

Run again after a Rex update or a change of Rex theme. Usage: rex-themes.py [out-dir]
"""
import json
import re
import subprocess
import sys
from pathlib import Path

REX_THEMES = Path("/Applications/Rex Beta.app/Contents/Resources/SuperUI_SuperDesignTokens.bundle/Contents/Resources/themes.json")
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / ".config/opencode/themes"
DEFAULTS = {"dark": "heliotrope-haze", "light": "lavender-postcard"}


def rgb(value):
    """A Rex CSS variable ("20 16 31", "rgb(255 126 219)", "rgb(… / 0.1)") or hex, as (r, g, b)."""
    if value.startswith("#"):
        return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))
    r, g, b = re.findall(r"[0-9.]+", value)[:3]
    return int(float(r)), int(float(g)), int(float(b))


def hex_(c):
    return "#%02x%02x%02x" % c


def mix(a, b, t):
    """`t` of the way from `a` to `b`."""
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def colors(theme):
    """OpenCode's V1 theme keys, from Rex's semantic CSS variables and ANSI palette."""
    v = {k.removeprefix("--super-"): rgb(val) for k, val in theme["cssVariables"].items() if k.startswith("--super-")}
    ansi = [rgb(c) for c in theme["source"]["ansi"]]
    bg, text = v["term-bg"], v["text"]
    accent, danger, success, warning, info = v["accent"], v["danger"], v["success"], v["warning"], v["info"]
    muted, faint = v["text-secondary"], v["text-tertiary"]
    tint = lambda c, t: mix(bg, c, t)
    c = {
        "primary": accent, "secondary": ansi[5], "accent": accent,
        "error": danger, "warning": warning, "success": success, "info": info,
        "text": text, "textMuted": muted,
        "background": bg, "backgroundPanel": v["sidebar"], "backgroundElement": v["raised"],
        "border": v["border"], "borderActive": v["border-strong"], "borderSubtle": mix(bg, v["border"], 0.5),
        "diffAdded": success, "diffRemoved": danger, "diffContext": muted, "diffHunkHeader": info,
        "diffHighlightAdded": ansi[10], "diffHighlightRemoved": ansi[9],
        "diffAddedBg": tint(success, 0.14), "diffRemovedBg": tint(danger, 0.14), "diffContextBg": v["sidebar"],
        "diffLineNumber": faint, "diffAddedLineNumberBg": tint(success, 0.09), "diffRemovedLineNumberBg": tint(danger, 0.09),
        "markdownText": text, "markdownHeading": accent, "markdownLink": info, "markdownLinkText": ansi[6],
        "markdownCode": success, "markdownBlockQuote": warning, "markdownEmph": warning, "markdownStrong": ansi[11],
        "markdownHorizontalRule": faint, "markdownListItem": info, "markdownListEnumeration": ansi[6],
        "markdownImage": info, "markdownImageText": ansi[6], "markdownCodeBlock": text,
        "syntaxComment": faint, "syntaxKeyword": ansi[5], "syntaxFunction": ansi[4], "syntaxVariable": ansi[1],
        "syntaxString": ansi[2], "syntaxNumber": ansi[9], "syntaxType": ansi[3], "syntaxOperator": ansi[6],
        "syntaxPunctuation": muted,
    }
    return {k: hex_(val) for k, val in c.items()}


def document(dark, light):
    return {
        "$schema": "https://opencode.ai/theme.json",
        "theme": {key: {"dark": dark[key], "light": light[key]} for key in dark},
    }


def rex_setting(key):
    out = subprocess.run(["defaults", "read", "com.superlogical.rex", key], capture_output=True, text=True)
    return out.stdout.strip() if out.returncode == 0 else ""


def main():
    themes = {t["id"]: t for t in json.loads(REX_THEMES.read_text())}
    OUT.mkdir(parents=True, exist_ok=True)
    for id_, theme in themes.items():
        c = colors(theme)
        (OUT / f"rex-{id_}.json").write_text(json.dumps(document(c, c), indent=2) + "\n")
    pair = {mode: rex_setting(f"Workspace.{mode}ThemeID") or DEFAULTS[mode] for mode in ("dark", "light")}
    pair = {mode: id_ if id_ in themes else DEFAULTS[mode] for mode, id_ in pair.items()}
    (OUT / "rex.json").write_text(json.dumps(document(colors(themes[pair["dark"]]), colors(themes[pair["light"]])), indent=2) + "\n")
    print(f"{len(themes) + 1} themes in {OUT} (rex = {pair['dark']} / {pair['light']})")


if __name__ == "__main__":
    main()
