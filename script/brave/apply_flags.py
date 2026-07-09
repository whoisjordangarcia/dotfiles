#!/usr/bin/env python3
"""Enable brave://flags experiments from a list, additively, in Local State.

Soft: browser.enabled_labs_experiments is NOT HMAC-protected (unlike homepage /
search / startup), so a file edit survives relaunch. Additive: unions with
whatever is already enabled, never disabling flags you set yourself. Brave must
be CLOSED — Local State is rewritten on exit.
"""
import json
import os
import sys


def apply(brave_dir, flags):
    """Union `flags` into enabled_labs_experiments; returns (added, final)."""
    path = os.path.join(brave_dir, "Local State")
    with open(path) as f:
        ls = json.load(f)
    current = ls.setdefault("browser", {}).get("enabled_labs_experiments") or []
    added = sorted(set(flags) - set(current))
    final = sorted(set(current) | set(flags))
    ls["browser"]["enabled_labs_experiments"] = final
    with open(path, "w") as f:
        json.dump(ls, f, separators=(",", ":"))
    return added, final


def parse_list(path):
    with open(path) as f:
        return [ln.strip() for ln in f if ln.strip() and not ln.startswith("#")]


if __name__ == "__main__":
    brave_dir, flags_txt = sys.argv[1], sys.argv[2]
    added, final = apply(brave_dir, parse_list(flags_txt))
    print(f"flags: +{len(added)} new ({', '.join(added) or 'none'}); {len(final)} enabled total")
