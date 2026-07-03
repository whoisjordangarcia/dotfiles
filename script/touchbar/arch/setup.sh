#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_DIR/../../common/log.sh"

section "Touch Bar (tiny-dfr) — Intel T2"

# Only relevant on T2 MacBooks (apple_bce is the bridge to the Touch Bar bus).
if [[ ! -d /sys/module/apple_bce ]]; then
    info "apple_bce not loaded — not a T2 Mac. Skipping Touch Bar setup."
    exit 0
fi

if ! systemctl list-unit-files tiny-dfr.service &>/dev/null; then
    warn "tiny-dfr.service not found — install the 'tiny-dfr' package first. Skipping."
    exit 0
fi

DROPIN_SRC="$SCRIPT_DIR/../../../configs/systemd/tiny-dfr.service.d/override.conf"
DROPIN_DST=/etc/systemd/system/tiny-dfr.service.d/override.conf

step "Installing tiny-dfr drop-in (clears Apple-Silicon BindsTo + fixes boot ordering cycle)"
sudo install -Dm644 "$DROPIN_SRC" "$DROPIN_DST"

step "Reloading systemd and re-enabling tiny-dfr under graphical.target"
sudo systemctl daemon-reload
# reenable rebuilds the wants symlinks from [Install], clearing any stale
# multi-user.target.wants/tiny-dfr.service link that caused the ordering cycle.
sudo systemctl reenable tiny-dfr.service

# Verify the BindsTo clearing actually took (the bug was a missing daemon-reload).
if systemctl show tiny-dfr -p BindsTo | grep -q '^BindsTo=$'; then
    success "tiny-dfr BindsTo cleared — daemon can start on boot."
else
    warn "tiny-dfr still reports: $(systemctl show tiny-dfr -p BindsTo). Check drop-ins under /etc/systemd/system/tiny-dfr.service.d/."
fi

info "Touch Bar comes up on the next clean boot. If it's blank after suspend, run: fix-touchbar"
