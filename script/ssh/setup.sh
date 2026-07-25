#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
DOTFILES_ROOT=$(cd -- "$SCRIPT_DIR/../.." &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

# Ensure ~/.ssh exists with correct permissions
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Create sockets directory for ControlMaster multiplexing
mkdir -p "$HOME/.ssh/sockets"

# Symlink the base SSH config (contains Include + global defaults)
link_file "$DOTFILES_ROOT/configs/ssh/config" "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config" 2>/dev/null || true

# Allowed signers for SSH commit signature verification (public keys only).
# The signing key itself is a FIDO handle (~/.ssh/id_ed25519_sk_git) — useless
# without the physical YubiKey, but NOT regenerable: copy it from an existing
# machine when setting up a new one.
link_file "$DOTFILES_ROOT/configs/ssh/allowed_signers" "$HOME/.ssh/allowed_signers"
if [[ ! -f "$HOME/.ssh/id_ed25519_sk_git" ]]; then
	info "Commit-signing key handle missing — copy ~/.ssh/id_ed25519_sk_git{,.pub} from another machine (needs the YubiKey to sign)"
fi

# Create hosts.local if it doesn't exist (machine-specific, not in git)
if [[ ! -f "$HOME/.ssh/hosts.local" ]]; then
	cat > "$HOME/.ssh/hosts.local" <<'EOF'
# Machine-specific SSH host aliases (not tracked in git)
#
# Example:
#   Host proxmox
#       HostName 192.168.1.100
#       User root
#
#   Host lxc-media
#       HostName 192.168.1.201
#       User jordan
#       ProxyJump proxmox
EOF
	chmod 600 "$HOME/.ssh/hosts.local"
	info "Created ~/.ssh/hosts.local — add your host aliases there"
else
	info "~/.ssh/hosts.local already exists, keeping your hosts"
fi

# ── GitHub SSH key setup ────────────────────────────────────────────────────

_github_ssh_works() {
	ssh -T -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 git@github.com 2>&1 | grep -q "successfully authenticated"
}

_copy_to_clipboard() {
	local pubkey="$1"
	if command -v pbcopy &>/dev/null; then
		pbcopy < "$pubkey"
	elif command -v xclip &>/dev/null; then
		xclip -selection clipboard < "$pubkey"
	elif command -v xsel &>/dev/null; then
		xsel --clipboard --input < "$pubkey"
	else
		return 1
	fi
}

section "GitHub SSH"

if _github_ssh_works; then
	success "GitHub SSH already working — skipping key generation"
else
	GITHUB_KEY="$HOME/.ssh/id_ed25519_github"

	# Generate key if it doesn't exist yet
	if [[ ! -f "$GITHUB_KEY" ]]; then
		# Determine email for key comment
		DOTCONFIG="$DOTFILES_ROOT/.dotconfig"
		KEY_EMAIL=""
		if [[ -z "${DOT_EMAIL:-}" && -f "$DOTCONFIG" ]]; then
			source "$DOTCONFIG"
		fi
		KEY_EMAIL="${DOT_EMAIL:-$(git config --global user.email 2>/dev/null || echo "")}"

		step "Generating ed25519 GitHub SSH key${KEY_EMAIL:+ for $KEY_EMAIL}..."
		ssh-keygen -t ed25519 -C "${KEY_EMAIL:-github}" -f "$GITHUB_KEY" -N ""
		chmod 600 "$GITHUB_KEY"
		chmod 644 "${GITHUB_KEY}.pub"
		success "Key generated at $GITHUB_KEY"
	else
		info "Key already exists at $GITHUB_KEY"
	fi

	# Add to ssh-agent. Start one ONLY if none is reachable (`ssh-add -l` exits 2
	# for "no agent", 1 for "agent, no keys"): eval'ing ssh-agent unconditionally
	# leaks a fresh agent on every run and loads the key into that throwaway
	# instead of the agent the user's shell talks to.
	AGENT_STATE=0
	ssh-add -l &>/dev/null || AGENT_STATE=$?
	if [[ "$AGENT_STATE" -eq 2 ]]; then
		eval "$(ssh-agent -s)" &>/dev/null || true
	fi
	if [[ "$(uname)" == "Darwin" ]]; then
		ssh-add --apple-use-keychain "$GITHUB_KEY" 2>/dev/null || ssh-add "$GITHUB_KEY"
	else
		ssh-add "$GITHUB_KEY" 2>/dev/null || true
	fi

	# Ensure the key we just generated is actually offered to GitHub.
	# NOT "is there a `Host github.com` stanza?" — configs/ssh/config ships one
	# (re-stating the default key), so that test is always true and this block
	# would never run, leaving the new key unreferenced and auth still failing.
	# IdentityFile is cumulative across matching blocks, so a second stanza here
	# adds a candidate rather than replacing one.
	if ! grep -q "$(basename "$GITHUB_KEY")" "$HOME/.ssh/hosts.local" 2>/dev/null; then
		cat >> "$HOME/.ssh/hosts.local" <<EOF

Host github.com
    IdentityFile $GITHUB_KEY
    AddKeysToAgent yes
EOF
		info "Added github.com entry to ~/.ssh/hosts.local"
	fi

	# Copy public key and prompt user to add it to GitHub
	PUBKEY="${GITHUB_KEY}.pub"
	echo ""
	info "Public key:"
	cat "$PUBKEY"
	echo ""

	if _copy_to_clipboard "$PUBKEY"; then
		info "Public key copied to clipboard."
	fi

	info "Add this key to GitHub: https://github.com/settings/ssh/new"
	info "Then press Enter to test the connection (or Ctrl+C to skip)..."
	read -r || true

	if _github_ssh_works; then
		success "GitHub SSH connection verified!"
	else
		info "Could not verify GitHub SSH — you can test later with: ssh -T git@github.com"
	fi
fi
