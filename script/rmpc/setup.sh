#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

# mpd/mpc/rmpc come from Brewfile.base. mpd is started on demand by the
# rmpc() wrapper in .zshrc.functions (which also mounts the NAS share via
# $NAS_SMB_URL from ~/.zshrc-modules/.zshrc.sec), so no service to enable.
mkdir -p "$HOME/.config/mpd/playlists" "$HOME/.config/rmpc/themes"
link_file "$SCRIPT_DIR/../../configs/mpd/mpd.conf" "$HOME/.config/mpd/mpd.conf"
link_file "$SCRIPT_DIR/../../configs/rmpc/config.ron" "$HOME/.config/rmpc/config.ron"
link_file "$SCRIPT_DIR/../../configs/rmpc/themes/catppuccin-macchiato.ron" "$HOME/.config/rmpc/themes/catppuccin-macchiato.ron"

info "rmpc setup done — set NAS_SMB_URL in ~/.zshrc-modules/.zshrc.sec if unset"
