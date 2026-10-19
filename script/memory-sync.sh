#!/usr/bin/env bash
# memory-sync — ONE memory file per machine, shared by every harness. No copies, so no drift.
#
#   ~/dev/dotfiles/configs/agents/AGENTS.md   canonical (git-tracked, the only file to edit; AGENTS.work.md on work)
#        │  memory-sync creates two symlinks to it
#        ├── ~/.claude/CLAUDE.md              Claude Code's user-scope memory
#        └── ~/.config/opencode/AGENTS.md     OpenCode's global memory
#
# Why symlinks and not one shared name: each harness fixes the *name* it looks for, and neither will read the
# other's. Claude Code's user scope is ~/.claude/CLAUDE.md and nothing else (~/.claude/AGENTS.md is never read);
# OpenCode's global is <config dir>/AGENTS.md. So each gets a link to the same inode — edit the canonical file
# and both harnesses see it next session, with nothing to copy and nothing to run.
#
# Tested and rejected: pointing OpenCode at the canonical file with an `instructions` entry in opencode.json.
# The key is in the published schema ("additional paths supplying ambient instructions") but beta-17823 ignores
# it — neither "~/dev/…" nor an absolute path nor a relative path loads. Re-test before trusting it again.
#
# No CLAUDE.local.md: a local instruction file is exactly what can switch a project off AGENTS.md. And no
# AGENTS.local.md — neither harness reads that name.
#
# `--check` reports drift without writing (exit 1 if a link needs rebuilding).
set -euo pipefail

this="$(readlink -f -- "${BASH_SOURCE[0]}")"
dotfiles="$(cd -- "$(dirname -- "$this")/.." && pwd)"
source "$dotfiles/script/common/dot_env.sh"
dot_export_env
# Work machines get their own memory: AGENTS.md describes the personal laptop, and the work rules
# (prod AWS, git workflow, Linear) must never follow a personal machine around.
if [ "$DOT_ENV" = "work" ]; then
	src="$dotfiles/configs/agents/AGENTS.work.md"
else
	src="$dotfiles/configs/agents/AGENTS.md"
fi

[ -f "$src" ] || { echo "missing canonical memory: $src" >&2; exit 1; }

check=0
[ "${1:-}" = "--check" ] && check=1

rc=0

# Each harness reads one fixed path; point it at the canonical file.
for link in "$HOME/.claude/CLAUDE.md" "$HOME/.config/opencode/AGENTS.md"; do
	if [ -L "$link" ] && [ "$(readlink -f -- "$link")" = "$src" ]; then
		continue
	fi
	if [ "$check" = 1 ]; then
		if [ -f "$link" ] && diff -q "$src" "$link" >/dev/null; then
			echo "NOTE: $link is a copy that happens to match; memory-sync will replace it with a symlink"
		else
			echo "STALE: $link is not a symlink to ${src#$dotfiles/} (run memory-sync)"
		fi
		rc=1
		continue
	fi
	mkdir -p "$(dirname "$link")"
	rm -f "$link"
	ln -s "$src" "$link"
	echo "linked $link -> $src"
done

# A stale pointer from the pre-AGENTS.md layout would count as a project instruction file.
for stale in "$HOME/.claude/CLAUDE.local.md"; do
	if [ -e "$stale" ] || [ -L "$stale" ]; then
		if [ "$check" = 1 ]; then
			echo "STALE: $stale exists; it switches projects off AGENTS.md (run memory-sync)"
			rc=1
		else
			rm -f "$stale"
			echo "removed $stale"
		fi
	fi
done

exit $rc
