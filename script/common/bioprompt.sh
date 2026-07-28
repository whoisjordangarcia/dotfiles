#!/usr/bin/env bash
# Shared builder for the macOS BioPrompt.app biometric helper.
#
# BioPrompt.app is the SwiftUI Touch ID / YubiKey approval dialog used by the
# touchid-gate.py PreToolUse hooks in BOTH Claude Code and Codex. Keeping the
# build in one place gives both clients a single app identity and one
# enrollment. This file is SOURCED by setup scripts, so it must not clobber the
# caller's SCRIPT_DIR — derive our own dir into a private var instead.
_BIOPROMPT_LIB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$_BIOPROMPT_LIB_DIR/log.sh"

# Build (or rebuild if stale) ~/Applications/BioPrompt.app and its
# ~/.local/bin/bioprompt shim. No-op off macOS or when swiftc is unavailable.
# Running the binary at its bundle path is what gives it app identity in the
# system auth UI, so the shim execs the bundled binary rather than a copy.
build_bioprompt() {
	[[ "$OSTYPE" == darwin* ]] || return 0
	command -v swiftc &>/dev/null || return 0

	local bioprompt_src="$_BIOPROMPT_LIB_DIR/../../configs/claude/hooks/bioprompt.swift"
	local bioprompt_plist="$_BIOPROMPT_LIB_DIR/../../configs/claude/hooks/bioprompt-Info.plist"
	local bioprompt_app="$HOME/Applications/BioPrompt.app"
	local bioprompt_bin="$bioprompt_app/Contents/MacOS/bioprompt"
	local bioprompt_shim="$HOME/.local/bin/bioprompt"

	if [[ ! -x "$bioprompt_bin" || "$bioprompt_src" -nt "$bioprompt_bin" || "$bioprompt_plist" -nt "$bioprompt_app/Contents/Info.plist" ]]; then
		step "Building BioPrompt.app (Touch ID helper)..."
		mkdir -p "$bioprompt_app/Contents/MacOS" "$(dirname "$bioprompt_shim")"
		cp "$bioprompt_plist" "$bioprompt_app/Contents/Info.plist"
		swiftc -O "$bioprompt_src" -o "$bioprompt_bin"
		printf '#!/bin/sh\nexec "%s" "$@"\n' "$bioprompt_bin" >"$bioprompt_shim"
		chmod +x "$bioprompt_shim"
		success "BioPrompt.app built at $bioprompt_app (shim: $bioprompt_shim)"
	else
		debug "BioPrompt.app already built and up to date. Skipping."
	fi

	# YubiKey tap-to-approve is enrolled per machine (credential lives in
	# ~/.config/bioprompt, never in this public repo).
	if [[ -x "$bioprompt_bin" && ! -f "$HOME/.config/bioprompt/cred.id" ]]; then
		info "YubiKey tap-to-approve not enrolled on this machine — run: bioprompt --enroll"
	fi
}
