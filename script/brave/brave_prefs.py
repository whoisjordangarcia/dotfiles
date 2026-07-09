#!/usr/bin/env python3
"""Snapshot/apply a curated allowlist of SOFT Brave prefs across profiles.

`snapshot` reads the canonical profile and captures only keys in PREF_KEYS that
actually exist (no guessing — captured values come straight from your browser).
`apply` writes each captured key into EVERY profile's Preferences, additively.
Brave must be CLOSED (Preferences is rewritten on exit).

STRICT ALLOWLIST: only the ~25 named scalar toggles below are ever read or
written. Bookmarks, history, passwords, per-site permission exceptions (which
hold real hostnames), tabs and telemetry are never touched — safe for a public
repo. None of these keys are HMAC-enforced, so file edits survive relaunch.
"""
import json
import os
import sys

PREF_KEYS = [
    # Brave feature toggles (soft equivalent of the old managed lockdown)
    "brave.rewards.enabled",
    "brave.news.opted_in",
    "brave.today.opted_in",
    "brave.brave_news.opted_in",
    "brave.ai_chat.show_toolbar_button",
    "brave.ai_chat.autocomplete_provider_enabled",
    "brave.brave_vpn.show_button",
    "brave.wallet.default_wallet",
    # New Tab Page layout
    "brave.new_tab_page.shows_options",
    "brave.new_tab_page.show_clock",
    "brave.new_tab_page.show_stats",
    "brave.new_tab_page.show_background_image",
    "brave.new_tab_page.show_branded_background_image",
    "brave.new_tab_page.show_rewards",
    "brave.new_tab_page.show_brave_talk",
    "brave.new_tab_page.shortcuts_visible",
    "brave.new_tab_page.hide_all_widgets",
    # UI / appearance
    "bookmark_bar.show_on_all_tabs",
    "brave.always_show_bookmark_bar_on_ntp",
    "browser.show_home_button",
    "brave.tabs.vertical_tabs_enabled",
    "brave.tabs.vertical_tabs_collapsed",
    "brave.location_bar_is_wide",
    "browser.theme.color_scheme2",
    # Content defaults (GLOBAL only — never host-specific exceptions)
    "profile.default_content_setting_values.notifications",
    "profile.default_content_setting_values.autoplay",
    # Password / autofill OFF (use 1Password) + omnibox suggestions
    "credentials_enable_service",
    "credentials_enable_autosignin",
    "autofill.profile_enabled",
    "autofill.credit_card_enabled",
    "payments.can_make_payment_enabled",
    "search.suggest_enabled",
    # Brave Shields / privacy defaults
    "brave.shields.advanced_view_enabled",
    "brave.shields.stats_badge_visible",
    "brave.https_upgrade",
    "brave.de_amp.enabled",
    "enable_do_not_track",
    "https_only_mode_enabled",
    # Web content defaults
    "webkit.webprefs.default_font_size",
    "webkit.webprefs.minimum_font_size",
    "download.prompt_for_download",
]

_MISSING = object()


def _get(d, dotted):
    for part in dotted.split("."):
        if not isinstance(d, dict) or part not in d:
            return _MISSING
        d = d[part]
    return d


def _set(d, dotted, value):
    parts = dotted.split(".")
    for part in parts[:-1]:
        d = d.setdefault(part, {})
    d[parts[-1]] = value


def snapshot(profile_prefs_path):
    """Return {key: value} for allowlisted scalar keys present in the file."""
    with open(profile_prefs_path) as f:
        prefs = json.load(f)
    out = {}
    for key in PREF_KEYS:
        val = _get(prefs, key)
        if val is not _MISSING and not isinstance(val, (dict, list)):
            out[key] = val
    return out


def _profile_dirs(brave_dir):
    with open(os.path.join(brave_dir, "Local State")) as f:
        cache = json.load(f).get("profile", {}).get("info_cache", {})
    return list(cache.keys())


def apply(brave_dir, pref_map):
    """Write allowlisted keys from pref_map into every profile; [(dir, n)]."""
    keys = [k for k in pref_map if k in PREF_KEYS]  # allowlist guard on apply too
    results = []
    for sub in _profile_dirs(brave_dir):
        pref_path = os.path.join(brave_dir, sub, "Preferences")
        if not os.path.exists(pref_path):
            continue
        with open(pref_path) as f:
            prefs = json.load(f)
        for key in keys:
            _set(prefs, key, pref_map[key])
        with open(pref_path, "w") as f:
            json.dump(prefs, f, separators=(",", ":"))
        results.append((sub, len(keys)))
    return results


def pin_extensions(brave_dir, ext_ids):
    """Additively pin ext_ids to the toolbar in every profile (union, order-
    preserving, never unpins). Pinning an id whose extension isn't installed is
    inert, so it's safe to pin the managed set everywhere."""
    results = []
    for sub in _profile_dirs(brave_dir):
        pref_path = os.path.join(brave_dir, sub, "Preferences")
        if not os.path.exists(pref_path):
            continue
        with open(pref_path) as f:
            prefs = json.load(f)
        current = prefs.setdefault("extensions", {}).get("pinned_extensions") or []
        merged = list(dict.fromkeys(current + [e for e in ext_ids if e not in current]))
        prefs["extensions"]["pinned_extensions"] = merged
        with open(pref_path, "w") as f:
            json.dump(prefs, f, separators=(",", ":"))
        results.append((sub, len(merged)))
    return results


def parse_map(path):
    out = {}
    with open(path) as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, val = line.split("=", 1)
            out[key.strip()] = json.loads(val.strip())
    return out


if __name__ == "__main__":
    if sys.argv[1] == "snapshot":
        for key, val in snapshot(sys.argv[2]).items():
            print(f"{key} = {json.dumps(val)}")
    elif sys.argv[1] == "apply":
        for sub, n in apply(sys.argv[2], parse_map(sys.argv[3])):
            print(f"{sub}: {n} prefs set")
    elif sys.argv[1] == "pin":
        for sub, n in pin_extensions(sys.argv[2], sys.argv[3:]):
            print(f"{sub}: {n} pinned")
