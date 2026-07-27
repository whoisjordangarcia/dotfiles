#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
COMPONENT_ROOT="$SCRIPT_DIR"
DOTFILES_ROOT=$(cd -- "$COMPONENT_ROOT/../../.." &>/dev/null && pwd)

source "$COMPONENT_ROOT/../../common/log.sh"

GPU_SWITCH_SRC="$DOTFILES_ROOT/bin/gpu-switch"
GPU_SWITCH_DST="/usr/local/bin/gpu-switch"

if [ ! -f "$GPU_SWITCH_SRC" ]; then
	fail "gpu-switch script not found at $GPU_SWITCH_SRC"
fi

if [ -L "$GPU_SWITCH_DST" ] && [ "$(readlink "$GPU_SWITCH_DST")" = "$GPU_SWITCH_SRC" ]; then
	debug "gpu-switch already symlinked to $GPU_SWITCH_DST"
else
	info "Symlinking gpu-switch to $GPU_SWITCH_DST (requires sudo)"
	sudo ln -sf "$GPU_SWITCH_SRC" "$GPU_SWITCH_DST"
	success "gpu-switch installed to $GPU_SWITCH_DST"
fi

# dGPU power-off (T2 MacBooks only — needs gmux/vga_switcheroo). Without it the
# discrete GPU idles at ~7W and its SMU firmware reload fails on most S3 resumes,
# which permanently breaks suspend for the session. See bin/dgpu-off.
if [ -e /sys/kernel/debug/vgaswitcheroo/switch ] || [ -d /sys/module/apple_gmux ]; then
	DGPU_OFF_SRC="$DOTFILES_ROOT/bin/dgpu-off"
	DGPU_OFF_DST="/usr/local/bin/dgpu-off"

	if [ -L "$DGPU_OFF_DST" ] && [ "$(readlink "$DGPU_OFF_DST")" = "$DGPU_OFF_SRC" ]; then
		debug "dgpu-off already symlinked to $DGPU_OFF_DST"
	else
		info "Symlinking dgpu-off to $DGPU_OFF_DST (requires sudo)"
		sudo ln -sf "$DGPU_OFF_SRC" "$DGPU_OFF_DST"
		success "dgpu-off installed to $DGPU_OFF_DST"
	fi

	info "Installing dgpu-off.service (boot + resume)"
	sudo install -m644 "$DOTFILES_ROOT/configs/systemd/dgpu-off.service" /etc/systemd/system/
	sudo systemctl daemon-reload
	sudo systemctl enable dgpu-off.service
	success "dgpu-off.service enabled"
else
	debug "No gmux/vga_switcheroo — skipping dgpu-off (not a dual-GPU MacBook)"
fi
