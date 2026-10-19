#!/usr/bin/env bash
# install.sh — install third-party agent skills from skills.sh, for every agent.
#
#   bash script/skills/install.sh                       # the manifest in configs/skills/THIRD-PARTY.md
#   bash script/skills/install.sh <name> <source> [...] # specific ones, e.g. agent-browser vercel-labs/agent-browser
#   bash script/skills/install.sh --list               # what is installed and from where
#   bash script/skills/install.sh --update             # refresh the installed ones
#
# Skills written for this machine live in configs/skills/ and are symlinked into the farms by
# script/skills/setup.sh; this script only fetches the third-party ones, so they track upstream instead of rotting
# as vendored copies. `npx skills add -g -a '*'` writes into every agent directory the CLI knows (Claude Code, Codex,
# Cursor, OpenCode, Pi), which is what makes one command enough for all four harnesses.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
DOTFILES=$(cd -- "$SCRIPT_DIR/../.." && pwd)
MANIFEST="$DOTFILES/configs/skills/THIRD-PARTY.md"

# name:source pairs — the single source of truth, mirrored in the manifest table.
MANIFEST_SKILLS=(
	"agent-browser:vercel-labs/agent-browser"
	"find-skills:vercel-labs/skills"
	"vercel-react-best-practices:vercel-labs/agent-skills"
	"vercel-composition-patterns:vercel-labs/agent-skills"
	"web-design-guidelines:vercel-labs/agent-skills"
	"mobile-ios-design:wshobson/agents"
	"gws-calendar:googleworkspace/cli"
	"gws-docs:googleworkspace/cli"
	"gws-sheets:googleworkspace/cli"
)

skills() { command -v npx >/dev/null 2>&1; }

case "${1:-}" in
--list)
	cd "$HOME" && npx -y skills@latest ls -g
	exit
	;;
--update)
	cd "$HOME" && npx -y skills@latest update -g -y
	exit
	;;
esac

# Explicit arguments: <name> <source> pairs.
if [ $# -gt 0 ]; then
	MANIFEST_SKILLS=()
	while [ $# -gt 0 ]; do
		MANIFEST_SKILLS+=("$1:$2")
		shift 2
	done
fi

if ! skills; then
	echo "npx not found — install Node, or read $MANIFEST and fetch the skills by hand" >&2
	exit 1
fi
# The CLI imports glob from fs/promises, which Node gained in 22.
if [ "$(node -p 'process.versions.node.split(".")[0]')" -lt 22 ]; then
	echo "skills CLI needs Node 22+, found $(node -v) — switch with nvm first" >&2
	exit 1
fi

failed=()
for pair in "${MANIFEST_SKILLS[@]}"; do
	name=${pair%%:*}
	source=${pair#*:}
	printf '%-30s %s\n' "$name" "$source"
	if ! (cd "$HOME" && npx -y skills@latest add "$source" -g -a '*' --copy -y -s "$name"); then
		failed+=("$name")
	fi
done

echo
(cd "$HOME" && npx -y skills@latest ls -g) || true
if [ ${#failed[@]} -gt 0 ]; then
	echo "failed: ${failed[*]} — check the source in $MANIFEST" >&2
	exit 1
fi
echo "all installed for every agent (Claude Code, Codex, Cursor, OpenCode, Pi)"