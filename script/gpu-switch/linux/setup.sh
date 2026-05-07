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
