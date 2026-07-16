#!/usr/bin/env python3
"""Set a distinct theme per Brave profile, matched by profile NAME.

Each profile gets either a built-in generated COLOR (#RRGGBB) or a Web Store
THEME (a 32-char extension id) — see profile-themes.txt.

Soft + additive: rewrites only the browser.theme / extensions.theme keys in each
profile's PLAIN Preferences (never the HMAC-signed Secure Preferences), leaving
every other pref untouched. Brave must be CLOSED or it overwrites these on exit.

The color format is exactly what Brave writes for a built-in "generated" color
theme, verified against a real profile: user_color2 is a signed 32-bit ARGB int.

Web Store themes are installed browser-wide by the soft installer (setup.sh reads
the ids out of profile-themes.txt); which one is ACTIVE is per-profile and lives in
extensions.theme.id. Brave auto-activates a theme in every profile when it first
installs it, so the very first launch after adding one can show the wrong theme —
re-run `brave-theme` (with Brave closed) once the install has happened and it sticks.
"""
import json
import os
import re
import sys

COLOR_VARIANT = 2  # the generated-theme variant Brave uses for a picked color
GENERATED_THEME_ID = "user_color_theme_id"
# Chrome-family extension IDs are exactly 32 chars from a-p.
THEME_ID_RE = re.compile(r"^[a-p]{32}$")


def is_theme_id(value):
    """True if a profile-themes.txt value is a Web Store theme id, not a color."""
    return bool(THEME_ID_RE.match(value))


def hex_to_signed_argb(hex_color):
    """'#RRGGBB' -> signed 32-bit ARGB int as Brave stores it in user_color2."""
    rgb = int(hex_color.lstrip("#"), 16) & 0xFFFFFF
    argb = 0xFF000000 | rgb
    return argb - 2**32 if argb >= 2**31 else argb


def set_theme(prefs, value):
    """Additively set a generated color ('#RRGGBB') or Web Store theme id."""
    if is_theme_id(value):
        # A Web Store theme owns the whole appearance; drop the generated-color
        # keys so Brave can't fall back to them and leave the two fighting.
        theme = prefs.setdefault("browser", {}).setdefault("theme", {})
        theme.pop("user_color2", None)
        theme.pop("color_variant2", None)
        prefs.setdefault("extensions", {})["theme"] = {"id": value}
        return prefs
    prefs.setdefault("browser", {}).setdefault("theme", {})
    prefs["browser"]["theme"]["user_color2"] = hex_to_signed_argb(value)
    prefs["browser"]["theme"]["color_variant2"] = COLOR_VARIANT
    prefs.setdefault("extensions", {})["theme"] = {"id": GENERATED_THEME_ID}
    return prefs


def profiles_by_name(brave_dir):
    """Map profile display-name -> profile subdir, from Local State."""
    ls = json.load(open(os.path.join(brave_dir, "Local State")))
    cache = ls.get("profile", {}).get("info_cache", {})
    return {meta.get("name"): d for d, meta in cache.items()}


def apply(brave_dir, theme_map):
    """Apply theme_map {name: '#RRGGBB' | '<theme id>'}; returns [(name, action)]."""
    results = []
    name_to_dir = profiles_by_name(brave_dir)
    for name, value in theme_map.items():
        subdir = name_to_dir.get(name)
        if not subdir:
            results.append((name, "no-such-profile"))
            continue
        pref_path = os.path.join(brave_dir, subdir, "Preferences")
        with open(pref_path) as f:
            prefs = json.load(f)
        set_theme(prefs, value)
        with open(pref_path, "w") as f:
            json.dump(prefs, f, separators=(",", ":"))
        kind = "theme" if is_theme_id(value) else "color"
        results.append((name, f"set {kind} {value}"))
    return results


def theme_ids(theme_map):
    """The Web Store theme ids in a theme map — these need soft-installing."""
    return [v for v in theme_map.values() if is_theme_id(v)]


def parse_map(path):
    """Read '<Name>=#RRGGBB' lines; full-line '#' comments only."""
    out = {}
    with open(path) as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, val = line.split("=", 1)
            out[key.strip()] = val.strip()
    return out


if __name__ == "__main__":
    # `ids <themes.txt>` prints the Web Store theme ids for the soft installer;
    # the default form applies the map to a Brave dir.
    if sys.argv[1] == "ids":
        for theme_id in theme_ids(parse_map(sys.argv[2])):
            print(theme_id)
    else:
        brave_dir, themes_txt = sys.argv[1], sys.argv[2]
        for name, action in apply(brave_dir, parse_map(themes_txt)):
            print(f"{name}: {action}")
