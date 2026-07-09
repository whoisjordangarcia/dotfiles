#!/usr/bin/env python3
"""Set a distinct built-in color theme per Brave profile, matched by profile NAME.

Soft + additive: rewrites only the browser.theme / extensions.theme keys in each
profile's PLAIN Preferences (never the HMAC-signed Secure Preferences), leaving
every other pref untouched. Brave must be CLOSED or it overwrites these on exit.

The color format is exactly what Brave writes for a built-in "generated" color
theme, verified against a real profile: user_color2 is a signed 32-bit ARGB int.
"""
import json
import os
import sys

COLOR_VARIANT = 2  # the generated-theme variant Brave uses for a picked color
GENERATED_THEME_ID = "user_color_theme_id"


def hex_to_signed_argb(hex_color):
    """'#RRGGBB' -> signed 32-bit ARGB int as Brave stores it in user_color2."""
    rgb = int(hex_color.lstrip("#"), 16) & 0xFFFFFF
    argb = 0xFF000000 | rgb
    return argb - 2**32 if argb >= 2**31 else argb


def set_theme(prefs, hex_color):
    """Additively set the generated color theme in a Preferences dict."""
    prefs.setdefault("browser", {}).setdefault("theme", {})
    prefs["browser"]["theme"]["user_color2"] = hex_to_signed_argb(hex_color)
    prefs["browser"]["theme"]["color_variant2"] = COLOR_VARIANT
    prefs.setdefault("extensions", {})["theme"] = {"id": GENERATED_THEME_ID}
    return prefs


def profiles_by_name(brave_dir):
    """Map profile display-name -> profile subdir, from Local State."""
    ls = json.load(open(os.path.join(brave_dir, "Local State")))
    cache = ls.get("profile", {}).get("info_cache", {})
    return {meta.get("name"): d for d, meta in cache.items()}


def apply(brave_dir, theme_map):
    """Apply theme_map {name: '#RRGGBB'}; returns [(name, action)]."""
    results = []
    name_to_dir = profiles_by_name(brave_dir)
    for name, hex_color in theme_map.items():
        subdir = name_to_dir.get(name)
        if not subdir:
            results.append((name, "no-such-profile"))
            continue
        pref_path = os.path.join(brave_dir, subdir, "Preferences")
        with open(pref_path) as f:
            prefs = json.load(f)
        set_theme(prefs, hex_color)
        with open(pref_path, "w") as f:
            json.dump(prefs, f, separators=(",", ":"))
        results.append((name, f"set {hex_color}"))
    return results


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
    brave_dir, themes_txt = sys.argv[1], sys.argv[2]
    for name, action in apply(brave_dir, parse_map(themes_txt)):
        print(f"{name}: {action}")
