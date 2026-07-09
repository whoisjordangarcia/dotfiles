#!/usr/bin/env python3
"""Extract your user-installed, Web Store Brave extensions from a profile dir.

Pure logic + a tiny CLI so it's unit-testable against a fixture (see
sync_test.sh), the same "logic behind a test hook" split the statusline/tmux
scripts use. Prints one `<id>  # <name>` line per unique extension, unioned
across every profile under BRAVE_DIR and sorted by name.

"User-installed Web Store" = extensions.settings entries that are from_webstore
with location INTERNAL (1, a normal user install) or EXTERNAL_PREF_DOWNLOAD (6).
Location 6 matters: once our own soft-installer's `External Extensions` manifest
takes effect, Brave reclassifies the extension from 1 -> 6, so filtering on 1
alone would make the NEXT snapshot capture nothing and wipe the list. Brave's
built-in components (location 5, from_webstore False) and policy force-installs
(location 7) are excluded, as are themes and disabled (state==0) entries.
"""
import json
import os
import sys

# INTERNAL (user install) + EXTERNAL_PREF_DOWNLOAD (our own soft install).
USER_LOCATIONS = (1, 6)
STATE_DISABLED = 0


def _load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def extract(brave_dir):
    """Return sorted [(id, name)] of user-installed Web Store extensions."""
    found = {}  # id -> display name (first profile wins; ids dedupe the union)
    for entry in sorted(os.listdir(brave_dir)):
        profile = os.path.join(brave_dir, entry)
        if not os.path.isdir(profile):
            continue
        # extensions.settings lives in "Secure Preferences"; older Brave used
        # "Preferences". Read both and let ids dedupe.
        for pref_file in ("Secure Preferences", "Preferences"):
            settings = (
                _load(os.path.join(profile, pref_file))
                .get("extensions", {})
                .get("settings", {})
            )
            for ext_id, meta in settings.items():
                if len(ext_id) != 32:
                    continue
                if meta.get("location") not in USER_LOCATIONS:
                    continue
                if not meta.get("from_webstore"):
                    continue
                if meta.get("state") == STATE_DISABLED:
                    continue
                manifest = meta.get("manifest") or {}
                if "theme" in manifest:  # themes carry a (possibly empty) theme key
                    continue
                name = manifest.get("name") or ext_id
                if name.startswith("__MSG_"):  # unresolved i18n placeholder
                    name = ext_id
                found.setdefault(ext_id, name)
    return sorted(found.items(), key=lambda kv: kv[1].lower())


if __name__ == "__main__":
    base = sys.argv[1] if len(sys.argv) > 1 else "."
    for ext_id, name in extract(base):
        print(f"{ext_id}  # {name}")
