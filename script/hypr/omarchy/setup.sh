#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

# Omarchy owns ~/.config/hypr/hyprland.conf and its source-chain into
# ~/.local/share/omarchy — we only manage the override files that
# hyprland.conf sources last. Never link hyprland.conf itself, and never
# monitors.conf (machine-specific).
if [[ ! -d "$HOME/.local/share/omarchy" ]]; then
	info "Omarchy not detected (~/.local/share/omarchy missing). Skipping."
	exit 0
fi

CONFIG_SRC="$SCRIPT_DIR/../../../configs/hypr-omarchy"
HYPR_DIR="$HOME/.config/hypr"
mkdir -p "$HYPR_DIR"

for file in bindings.conf looknfeel.conf input.conf autostart.conf gpu-perf-intel.conf gpu-perf-amd.conf; do
	link_file "$CONFIG_SRC/$file" "$HYPR_DIR/$file"
done

# gpu-perf.conf is a machine-local symlink retargeted by gpu-switch;
# default to the lightweight Intel profile on first install.
if [[ ! -e "$HYPR_DIR/gpu-perf.conf" ]]; then
	ln -s "$HYPR_DIR/gpu-perf-intel.conf" "$HYPR_DIR/gpu-perf.conf"
	step "Defaulted gpu-perf.conf -> gpu-perf-intel.conf"
fi

# Machine-local bindings (private webapp URLs etc.) — sourced by
# bindings.conf, never committed (same pattern as ~/.ssh/hosts.local).
if [[ ! -f "$HYPR_DIR/bindings.local.conf" ]]; then
	cat >"$HYPR_DIR/bindings.local.conf" <<'EOF'
# Machine-local Hyprland bindings — NOT tracked in dotfiles.
# Private webapp URLs / host-specific launchers go here, e.g.:
# bindd = SUPER SHIFT, A, MyApp, exec, omarchy-launch-webapp "https://my.internal.host"
EOF
	step "Seeded $HYPR_DIR/bindings.local.conf"
fi

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl &>/dev/null; then
	hyprctl reload >/dev/null || true
	errors=$(hyprctl configerrors 2>/dev/null || true)
	if [[ -n "$errors" && "$errors" != *"no errors"* ]]; then
		warn "hyprctl configerrors: $errors"
	fi
fi

success "Omarchy Hyprland overrides linked"
