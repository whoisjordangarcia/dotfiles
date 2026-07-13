#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

# mpd/mpc/rmpc come from Brewfile.base. mpd is started on demand by the
# rmpc() wrapper in .zshrc.functions (which also mounts the NAS share via
# $NAS_SMB_URL from ~/.zshrc-sec), so no service to enable.
mkdir -p "$HOME/.config/mpd/playlists" "$HOME/.config/rmpc/themes"
link_file "$SCRIPT_DIR/../../configs/mpd/mpd.conf" "$HOME/.config/mpd/mpd.conf"
link_file "$SCRIPT_DIR/../../configs/rmpc/config.ron" "$HOME/.config/rmpc/config.ron"
link_file "$SCRIPT_DIR/../../configs/rmpc/themes/catppuccin-macchiato.ron" "$HOME/.config/rmpc/themes/catppuccin-macchiato.ron"

# rmpc() needs $NAS_SMB_URL to mount the share. It belongs in ~/.zshrc-sec — NOT
# ~/.zshrc-modules/.zshrc.sec, which script/zsh/setup.sh regenerates from the
# 1Password template on every run, destroying anything hand-written there.
# The URL holds a real LAN address, so it can never live in this public repo;
# seed a placeholder instead so a fresh machine knows what to fill in.
LOCAL_SEC="$HOME/.zshrc-sec"

# Seed the placeholder only if the var is absent entirely. Matching on the
# *commented* placeholder too is what keeps this idempotent — a guard that only
# looked for an active `export` would re-append on every run until it was
# filled in.
if ! grep -qs 'NAS_SMB_URL' "$LOCAL_SEC"; then
	{
		[ -s "$LOCAL_SEC" ] || echo "#!/bin/zsh"
		echo ""
		echo "# NAS SMB share for rmpc()/mpd — uncomment and point at the share"
		echo "# holding Music-clean (see music_directory in configs/mpd/mpd.conf)."
		echo '#export NAS_SMB_URL="smb://user@host/tank01"'
	} >>"$LOCAL_SEC"
	chmod 600 "$LOCAL_SEC"
fi

if grep -qs '^[[:space:]]*export[[:space:]]\{1,\}NAS_SMB_URL=' "$LOCAL_SEC"; then
	debug "NAS_SMB_URL already set in ~/.zshrc-sec. Skipping."
else
	info "NAS_SMB_URL not set — uncomment it in ~/.zshrc-sec to enable rmpc"
fi

info "rmpc setup done"
