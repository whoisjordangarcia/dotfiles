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

# Since tiny-dfr v0.3.7 the package ships t2-intel.conf (clears the
# Apple-Silicon BindsTo= and installs under graphical.target) — the fix our
# old local override.conf used to apply. A leftover local override with
# WantedBy=multi-user.target creates an ordering cycle that silently drops
# the unit at boot, so remove it and rebuild the wants symlinks.
if [[ ! -f /usr/lib/systemd/system/tiny-dfr.service.d/t2-intel.conf ]]; then
    warn "Package t2-intel.conf drop-in missing — tiny-dfr too old? Update the package. Skipping."
    exit 0
fi

STALE=/etc/systemd/system/tiny-dfr.service.d/override.conf
if [[ -f $STALE ]]; then
    step "Removing stale local override (superseded by package t2-intel.conf)"
    sudo rm "$STALE"
    sudo rmdir --ignore-fail-on-non-empty /etc/systemd/system/tiny-dfr.service.d
fi

step "Installing T2 suspend/resume module fix (deep sleep hangs with T2 modules loaded)"
CFG="$SCRIPT_DIR/../../../configs"
sudo install -m644 "$CFG/systemd/suspend-fix-t2.service" "$CFG/systemd/resume-fix-t2.service" /etc/systemd/system/
sudo install -Dm644 "$CFG/systemd/sleep.conf.d/t2-no-hibernate.conf" /etc/systemd/sleep.conf.d/t2-no-hibernate.conf
sudo install -Dm644 "$CFG/systemd/systemd-suspend.service.d/resume-fix-on-failure.conf" \
    /etc/systemd/system/systemd-suspend.service.d/resume-fix-on-failure.conf
sudo install -m644 "$CFG/udev/99-touchbar-power.rules" /etc/udev/rules.d/
sudo udevadm control --reload-rules

# Superseded by the suspend/resume pair (they unloaded modules but never
# reloaded them, leaving the machine without input/WiFi after wake).
# resume-wifi-reload also raced resume-fix-t2 modprobing the same modules and
# called /usr/bin/nmcli, which doesn't exist here (omarchy uses iwd).
for stale in suspend-wifi-unload resume-wifi-reload; do
    if systemctl list-unit-files "$stale.service" &>/dev/null; then
        step "Removing old $stale.service (superseded by suspend/resume-fix-t2)"
        sudo systemctl disable "$stale.service" 2>/dev/null || true
        sudo rm -f "/etc/systemd/system/$stale.service"
    fi
done
sudo rm -f /usr/local/bin/t2-wait-apple-bce.sh /usr/local/bin/fix-kbd-backlight.sh

step "Reloading systemd and enabling tiny-dfr + suspend/resume services"
sudo systemctl daemon-reload
sudo systemctl reenable tiny-dfr.service
sudo systemctl enable suspend-fix-t2.service resume-fix-t2.service

# Verify: BindsTo cleared and no multi-user wants link (the ordering-cycle bug).
if systemctl show tiny-dfr -p BindsTo | grep -q '^BindsTo=$' \
    && [[ ! -e /etc/systemd/system/multi-user.target.wants/tiny-dfr.service ]]; then
    success "tiny-dfr enabled under graphical.target — starts on boot."
else
    warn "tiny-dfr still misconfigured: $(systemctl show tiny-dfr -p BindsTo); check /etc/systemd/system/*.wants/tiny-dfr.service."
fi

info "Touch Bar comes up on the next clean boot. If it's blank after suspend, run: fix-touchbar"
