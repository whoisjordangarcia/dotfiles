#!/bin/bash
# Sunshine prep-cmd helpers.
#
# Design: Sunshine's wlroots backend captures monitor INDEX 0, never a named
# output (output_name is parsed as an integer, so names like "MAIN" resolve to
# index 0). The persistent headless output "MAIN" is that index-0 monitor —
# every stream captures MAIN. Per-stream prep therefore resizes MAIN to the
# client's native canvas and undo restores the desk default; no second output
# is ever created. Physical monitors (HDMI-A-1, DP-1, …) are NEVER touched.
#
# (Historical: profiles used to create an ephemeral "MOONLIGHT" output per
# stream, believing Sunshine captured it by name. Falsified 2026-07-25 — it
# was never captured, and its phantom workspace swallowed new windows.
# restore_capture_display remains only to clean up any stale leftover.)
#
# prep_main_display <mode-spec>
#   Sweeps stray/stale outputs, then applies the given mode to MAIN.
#   <mode-spec> example: "1920x1080@120,0x0,1,bitdepth,10"
#
# restore_main_display
#   Restores MAIN to the desk-default mode below.

MAIN_NAME="MAIN"
# Desk default — must match monitors.conf.
MAIN_DEFAULT_MODE="3840x2160@144.0,0x0,1.5,bitdepth,10"

# Legacy ephemeral output; only ever removed now, never created.
CAPTURE_NAME="MOONLIGHT"

# Public alias so prep-cmds that don't need the display helpers
# can still reuse the env discovery logic.
ensure_hyprland_env() { _require_hyprland "$@"; }

_require_hyprland() {
    # Sunshine often runs as root (capabilities for KMS / uinput) which strips
    # the user's env. Auto-discover the Hyprland socket from /run/user/<uid>/hypr/
    # and set XDG_RUNTIME_DIR so hyprctl can reach the user's compositor.
    if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || [ ! -d "${XDG_RUNTIME_DIR:-/nonexistent}/hypr" ]; then
        local uid=1000
        local runtime="/run/user/$uid"
        if [ -d "$runtime/hypr" ]; then
            export XDG_RUNTIME_DIR="$runtime"
            local sig
            sig=$(ls -1t "$runtime/hypr" 2>/dev/null | head -1)
            if [ -n "$sig" ]; then
                export HYPRLAND_INSTANCE_SIGNATURE="$sig"
            fi
        fi
    fi

    if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        echo "sunshine_display: no Hyprland socket found in /run/user/1000/hypr" >&2
        return 1
    fi
    hyprctl version >/dev/null 2>&1 || {
        echo "sunshine_display: hyprctl can't reach Hyprland (sig=$HYPRLAND_INSTANCE_SIGNATURE)" >&2
        return 1
    }
}

# Informational only — log which physical port currently has a monitor plugged
# in. We never act on this; it's just for journalctl debugging.
_log_physical_outputs() {
    local connected=()
    for st in /sys/class/drm/card*-{HDMI-A,DP}-*/status; do
        [ -f "$st" ] || continue
        if [ "$(cat "$st")" = "connected" ]; then
            local port="${st#*card?-}"; port="${port%/status}"
            connected+=("$port")
        fi
    done
    echo "sunshine_display: physical outputs connected: ${connected[*]:-none}"
}

_capture_exists() {
    hyprctl monitors all 2>/dev/null \
        | awk -v n="$CAPTURE_NAME" '$1=="Monitor" && $2==n {f=1} END{exit !f}'
}

# A stray auto-created HEADLESS-N fallback output (Hyprland booting with no
# monitors) would steal index 0 from MAIN and every stream would capture an
# empty screen — drop strays before each stream. Also removes any stale
# MOONLIGHT leaked by the pre-2026-07-25 design or a failed undo.
sweep_stray_outputs() {
    hyprctl monitors all 2>/dev/null \
        | awk '$1=="Monitor" && $2~/^HEADLESS-/{print $2}' \
        | while read -r stray; do
            hyprctl output remove "$stray" >/dev/null 2>&1 || true
        done
    if _capture_exists; then
        hyprctl output remove "$CAPTURE_NAME" >/dev/null 2>&1 || true
    fi
}

prep_main_display() {
    local mode_spec="$1"
    if [ -z "$mode_spec" ]; then
        echo "prep_main_display: missing mode-spec" >&2
        return 1
    fi
    _require_hyprland || return 1
    _log_physical_outputs
    sweep_stray_outputs
    hyprctl keyword monitor "$MAIN_NAME,$mode_spec" >/dev/null
    echo "$MAIN_NAME"
}

restore_main_display() {
    _require_hyprland || return 1
    sweep_stray_outputs
    hyprctl keyword monitor "$MAIN_NAME,$MAIN_DEFAULT_MODE" >/dev/null
}

# Legacy cleanup: remove a stale MOONLIGHT output. No-op if it doesn't exist.
restore_capture_display() {
    _require_hyprland || return 1
    if _capture_exists; then
        hyprctl output remove "$CAPTURE_NAME" >/dev/null 2>&1 || true
    fi
}
