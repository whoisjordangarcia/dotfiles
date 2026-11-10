#!/bin/bash
# The statusLine command (linked as ~/.claude/statusline.sh). Every process started here is paid on
# every refresh, so only builtins run before the renderer.
IFS= read -r -d '' input
# Find statusline.ts with builtins: beside this file (run directly, or from a clone anywhere — CI), then the
# standard checkout (the live path: this file is reached through the ~/.claude/statusline.sh symlink).
# Only a clone somewhere else pays for a readlink.
ts="${BASH_SOURCE[0]%/*}/statusline.ts"
[ -f "$ts" ] || ts="$HOME/dev/dotfiles/configs/claude/plugins/statusline-mod/cli/statusline.ts"
if [ ! -f "$ts" ] && [ -L "${BASH_SOURCE[0]}" ]; then
  link=$(readlink "${BASH_SOURCE[0]}")
  ts="${link%/*}/statusline.ts"
fi

# bun starts in ~6ms against node's ~90ms. Node needs ≥ 22.18 to run .ts, and a session's PATH can lead
# with an older nvm node (a project's .nvmrc), so Homebrew's comes before PATH's.
for run in "$HOME/.bun/bin/bun" /opt/homebrew/bin/node "$(command -v node)"; do
  [ -x "$run" ] || continue
  if out=$("$run" "$ts" <<<"$input" 2>/dev/null); then
    printf '%s\n' "$out"
    exit 0
  fi
done

# Nothing could run it: the payload's basics rather than a blank row.
jq -r '[(.model.display_name // "?"), ("$" + ((.cost.total_cost_usd // 0) * 100 | round / 100 | tostring)),
  ((.context_window.used_percentage // 0 | round | tostring) + "%")] | join(" ⋮ ")' <<<"$input" 2>/dev/null
