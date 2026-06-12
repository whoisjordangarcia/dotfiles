#!/bin/zsh
# Secrets template (WORK) — rendered to .zshrc.sec by script/zsh/setup.sh
# (personal machines use .zshrc.sec.personal.tpl instead; selection via WORK_ENV)
#
# Two patterns:
#
#  1. INJECTED at setup — "{{ op://... }}" is replaced with the real value by
#     `op inject`, so PLAINTEXT lands in .zshrc.sec. Only for low-sensitivity
#     values needed in every shell.
#
#  2. LAZY (recommended for anything sensitive) — keep only the op://
#     reference; no secret material ever lands on disk. Fetch at use-time
#     with the `opsec` helper (Touch ID prompts via the 1Password app):
#       ELASTIC_STG_API_KEY=$(opsec "$ELASTIC_STG_API_KEY_REF") some-command
#
# Find paths with: op vault list  /  op item list --vault <vault>

# -- injected (plaintext at rest — use sparingly) --

# -- lazy references (safe to keep here; resolved per-use via opsec) --
# TODO: create the item first, then fix the op:// path:
#   op item create --vault Work --category "API Credential" --title "Elastic stg" credential=<key>
#export ELASTIC_STG_API_KEY_REF="op://Work/Elastic stg/credential"
