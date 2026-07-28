#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"
source "$SCRIPT_DIR/../common/bioprompt.sh"

# Make nvm-installed node available — this script runs as its own process,
# so it doesn't inherit nvm from the node component's shell.
# (nvm.sh is incompatible with `set -eu`, so relax around the source)
if ! command -v npm &>/dev/null && [ -s "$HOME/.nvm/nvm.sh" ]; then
    set +eu
    export NVM_DIR="$HOME/.nvm"
    \. "$NVM_DIR/nvm.sh"
    set -eu
fi

if ! command -v npm &>/dev/null; then
    fail "npm not found — skipping codex install. Run the node setup script first, then re-run this script."
fi

npm i -g @openai/codex -f

mkdir -p "$HOME/.codex"

# Stable Codex policy is symlinked so edits remain version-controlled. Codex
# keeps runtime-generated state in config.toml, which remains a copied seed.
mkdir -p "$HOME/.codex/rules" "$HOME/.codex/hooks"
link_file "$SCRIPT_DIR/../../configs/codex/AGENTS.md" "$HOME/.codex/AGENTS.md"
link_file "$SCRIPT_DIR/../../configs/codex/rules/default.rules" "$HOME/.codex/rules/dotfiles.rules"
link_file "$SCRIPT_DIR/../../configs/codex/hooks.json" "$HOME/.codex/hooks.json"
link_file "$SCRIPT_DIR/../../configs/codex/hooks/touchid-gate.py" "$HOME/.codex/hooks/touchid-gate.py"

# NOTE: the cosmetic cmux integrations (cmux-dispatch.py + the shared
# cmux_common/cmux-progress/cmux-pr scripts) are intentionally NOT wired here.
# bbae320 deleted those scripts from configs/claude/scripts, so linking them
# only produced dangling symlinks and a dispatcher that failed at runtime.

# Build the same macOS biometric helper used by Claude. Keeping the helper
# shared (script/common/bioprompt.sh) gives both clients one Touch ID/YubiKey
# enrollment and app identity.
build_bioprompt

# Codex owns ~/.codex/config.toml at runtime (it rewrites trust paths, marketplace
# state, desktop SHA256s, etc.), so we SEED it from a sanitized template instead of
# symlinking — symlinking would push that machine/work-specific state back into this
# public repo. Only seed when the file is absent so we never clobber a live config.
CODEX_TEMPLATE="$SCRIPT_DIR/../../configs/codex/config.toml.template"
CODEX_CONFIG="$HOME/.codex/config.toml"
if [ ! -e "$CODEX_CONFIG" ]; then
    step "Seeding $CODEX_CONFIG from template"
    cp "$CODEX_TEMPLATE" "$CODEX_CONFIG"
else
    info "$CODEX_CONFIG already exists — leaving it untouched"
fi

# Ensure the hooks feature flag + approval policy land on ALREADY-provisioned
# machines. Seeding above only runs on a fresh install, so an existing live
# config (which Codex owns) would otherwise never gain `approval_policy` or
# `[features] hooks = true`, leaving hooks.json / touchid-gate silently inert.
# This patch is idempotent and edits ONLY those two keys in place — nothing else
# in Codex's machine-owned config is touched. (python3 is on all target systems.)
if [ -e "$CODEX_CONFIG" ]; then
    _codex_cfg_changes=$(python3 - "$CODEX_CONFIG" <<'PY'
import re
import sys

path = sys.argv[1]
with open(path, "r") as f:
    text = f.read()

lines = text.split("\n")
changes = []

# 1) Ensure top-level approval_policy. Top-level keys must precede the first
#    table header, so scan only the region before the first `[...]` line and
#    insert there if absent.
first_table = len(lines)
for i, ln in enumerate(lines):
    if ln.lstrip().startswith("["):
        first_table = i
        break

has_ap = any(re.match(r"approval_policy\s*=", ln.strip()) for ln in lines[:first_table])
if not has_ap:
    lines.insert(first_table, 'approval_policy = "on-request"')
    changes.append('added top-level approval_policy = "on-request"')

# 2) Ensure [features] hooks = true (append the table if it doesn't exist).
feat_idx = None
for i, ln in enumerate(lines):
    if re.match(r"\[features\]\s*$", ln.strip()):
        feat_idx = i
        break

if feat_idx is None:
    while lines and lines[-1] == "":
        lines.pop()
    lines.extend(["", "[features]", "hooks = true", ""])
    changes.append("added [features] table with hooks = true")
else:
    has_hooks = False
    j = feat_idx + 1
    while j < len(lines):
        s = lines[j].strip()
        if s.startswith("["):
            break
        if re.match(r"hooks\s*=", s):
            has_hooks = True
            break
        j += 1
    if not has_hooks:
        lines.insert(feat_idx + 1, "hooks = true")
        changes.append("added hooks = true under [features]")

new_text = "\n".join(lines)
if new_text != text:
    with open(path, "w") as f:
        f.write(new_text)

for c in changes:
    print(c)
PY
)
    if [ -n "$_codex_cfg_changes" ]; then
        step "Patched hook settings into $CODEX_CONFIG"
        while IFS= read -r _line; do info "    $_line"; done <<< "$_codex_cfg_changes"
    else
        debug "$CODEX_CONFIG already has approval_policy + [features] hooks — no change"
    fi
fi

# Skills live in configs/skills and are projected into each agent CLI.
source "$SCRIPT_DIR/../skills/setup.sh"
