#!/bin/bash
# Guarantee the persistent "MAIN" headless output exists before Sunshine starts.
#
# Sunshine probes for a working video encoder at process startup. With no
# enabled Hyprland output (e.g. booting with the physical monitor off, or the
# login exec-once racing the compositor), that probe fails and the host comes
# up unable to stream. This anchor — run as an ExecStartPre of sunshine.service
# — creates MAIN if it's missing so the encoder probe always has a surface.
#
# monitors.conf sizes MAIN (3840x2160@144); per-stream prep-cmds resize MAIN
# itself to the client's canvas (it is the captured index-0 monitor) and
# restore it on disconnect — no second output is ever created.
source "$HOME/.config/sunshine/scripts/lib/sunshine_display.sh"

# Reuse the lib's socket auto-discovery. If the compositor is unreachable we
# exit 0 anyway — never block Sunshine startup on this best-effort anchor.
ensure_hyprland_env || exit 0

if ! hyprctl monitors all 2>/dev/null | awk '$1=="Monitor"{print $2}' | grep -qx MAIN; then
    hyprctl output create headless MAIN >/dev/null 2>&1 || exit 0
    sleep 0.3
fi

# Sunshine's wlroots backend captures by monitor INDEX, not name (output_name
# is parsed as an integer — "MAIN" always resolves to index 0). If Hyprland
# booted with no monitors it auto-creates a fallback HEADLESS-N output that
# steals index 0, so every stream captures that empty output → blank screen.
# Drop any such strays so MAIN is guaranteed to be monitor 0.
hyprctl monitors all 2>/dev/null | awk '$1=="Monitor" && $2~/^HEADLESS-/{print $2}' \
    | while read -r stray; do
        hyprctl output remove "$stray" >/dev/null 2>&1 || true
    done
exit 0
