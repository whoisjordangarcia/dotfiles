#!/usr/bin/env bash
# setup.sh — make every harness's skill directory agree, and keep the local skills in sync with the dotfiles.
#
# Layout that works with the skills.sh CLI (which owns ~/.agents/skills and rewrites it on every install):
#
#   ~/dev/dotfiles/configs/skills/*        source of truth for skills written for this machine
#        │ copied by this script
#        ▼
#   ~/.agents/skills/                     the global root: local copies + third-party installs (skills.sh)
#        │ symlinked by this script
#        ├── ~/.claude/skills             Claude Code
#        ├── ~/.codex/skills              Codex
#        └── ~/.cursor/skills             Cursor
#
# OpenCode reads ~/.agents/skills directly. Omarchy's own two skills (omarchy, diagnose-crash) stay symlinked to
# /usr/share/omarchy/default/agents/skills so an Omarchy update lands on its own.
# Third-party skills are fetched with script/skills/install.sh — never vendored in the dotfiles.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
DOTFILES=$(cd -- "$SCRIPT_DIR/../.." && pwd)
LOCAL="$DOTFILES/configs/skills"
OMARCHY=/usr/share/omarchy/default/agents/skills
GLOBAL="$HOME/.agents/skills"
FARMS=("$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.cursor/skills")

# 1. local skills → managed copies in the global root (the CLI owns that directory, so copies, not symlinks)
synced=0
for src in "$LOCAL"/*/; do
	[ -f "$src/SKILL.md" ] || continue # skips THIRD-PARTY.md and anything without a SKILL.md
	name=$(basename "$src")
	dst="$GLOBAL/$name"
	if [ -L "$dst" ] || ! [ -f "$dst/SKILL.md" ] || ! diff -rq "$src" "$dst" >/dev/null 2>&1; then
		rm -rf "$dst"
		cp -a "$src" "$dst"
		synced=$((synced + 1))
	fi
done

# 2. Omarchy's skills into the global root as links to its tree
for src in "$OMARCHY"/*/; do
	[ -f "$src/SKILL.md" ] || continue
	ln -sfn "$src" "$GLOBAL/$(basename "$src")"
done

# 3. every skill in the global root, linked into the other three farms
linked=0
for skill in "$GLOBAL"/*/; do
	[ -f "$skill/SKILL.md" ] || continue
	name=$(basename "$skill")
	for farm in "${FARMS[@]}"; do
		mkdir -p "$farm"
		target="$farm/$name"
		if [ -d "$target" ] && [ ! -L "$target" ]; then
			rm -rf "$target" # a copy left by an earlier install; the global root is the source now
		fi
		rm -f "$target"
		ln -s "$skill" "$target"
	done
	linked=$((linked + 1))
done
# prune anything the farms carry that the global root does not
for farm in "${FARMS[@]}"; do
	for entry in "$farm"/*; do
		[ -e "$entry" ] || continue
		name=$(basename "$entry")
		[ -d "$GLOBAL/$name" ] || rm -rf "$entry"
	done
done

broken=$(for farm in "$GLOBAL" "${FARMS[@]}"; do find "$farm" -maxdepth 1 -xtype l; done | wc -l)
printf 'local skills synced: %s (of %s)\n' "$synced" "$(find "$LOCAL" -maxdepth 2 -name SKILL.md | wc -l)"
printf 'skills in ~/.agents/skills: %s, linked into %s farms, %s broken links\n' "$linked" "${#FARMS[@]}" "$broken"
ls "$GLOBAL" | tr '\n' ' '
echo