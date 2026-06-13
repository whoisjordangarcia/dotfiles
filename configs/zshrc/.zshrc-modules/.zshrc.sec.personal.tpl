#!/bin/zsh
# Secrets template (PERSONAL) — rendered to .zshrc.sec by script/zsh/setup.sh
# (work machines use .zshrc.sec.work.tpl instead; selected via WORK_ENV)
#
# IMPORTANT: `op inject` tries to RESOLVE every 1Password reference in this
# file — even in comments — so the reference scheme never appears here bare.
# Double braces around a DOUBLE-QUOTED reference emit the literal string;
# double braces around an UNQUOTED reference inject the real secret value.
#
# Two patterns:
#
#  1. INJECTED at setup — unquoted reference in double braces is replaced
#     with the real value, so PLAINTEXT lands in .zshrc.sec. Only for
#     low-sensitivity values needed in every shell.
#
#  2. LAZY (recommended for anything sensitive) — keep the inner quotes so
#     only the reference STRING lands on disk, never the secret. Fetch at
#     use-time with the `opsec` helper (Touch ID via the 1Password app):
#       MY_KEY=$(opsec "$MY_KEY_REF") some-command
#
# Find paths with: op vault list  /  op item list --vault <vault>

# -- injected (plaintext at rest — use sparingly; remove inner quotes to arm) --
#export SOME_LOW_RISK_VALUE="{{ "op://Personal/Item/field" }}"

# -- lazy references (keep inner quotes; resolved per-use via opsec) --
#export ANTHROPIC_API_KEY_REF="{{ "op://Personal/Anthropic/credential" }}"
