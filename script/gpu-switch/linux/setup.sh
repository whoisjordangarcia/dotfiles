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

# dgpu-off is NOT installed — it hard-crashes suspend. Powering the dGPU down via
# gmux leaves amdgpu bound, and amdgpu_pmops_suspend_noirq() ignores
# DRM_SWITCH_POWER_OFF and resets the ASIC anyway; on a depowered GPU that returns
# -EINVAL, failing suspend in the noirq phase, which can't unwind — xhci_hcd and
# the T2 bridge go down with it and the machine reboots (2026-07-26). Full
# write-up and the untested fix in bin/dgpu-off's header. Tear down any install
# left over from before that date.
if [ -e /etc/systemd/system/dgpu-off.service ] || [ -L /usr/local/bin/dgpu-off ]; then
	info "Removing dgpu-off (breaks S3 suspend — see bin/dgpu-off)"
	sudo systemctl disable --now dgpu-off.service 2>/dev/null || true
	sudo rm -f /etc/systemd/system/dgpu-off.service /usr/local/bin/dgpu-off
	sudo systemctl daemon-reload
	success "dgpu-off removed"
fi
