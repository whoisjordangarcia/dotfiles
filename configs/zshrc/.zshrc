if [[ -n "$SSH_CONNECTION" ]]; then export TERM=xterm-256color; fi

# Keep $PATH entries unique so re-sourcing this file (e.g. `reload`) is
# idempotent — without this, every prepend in .zshrc.{envvars,paths} stacks
# another duplicate copy onto PATH.
typeset -U path PATH

# defaults
source ~/.zshrc-modules/.zshrc.history
source ~/.zshrc-modules/.zshrc.init
source ~/.zshrc-modules/.zshrc.plugins
source ~/.zshrc-modules/.zshrc.envvars
source ~/.zshrc-modules/.zshrc.aliases
source ~/.zshrc-modules/.zshrc.functions
source ~/.zshrc-modules/.zshrc.paths
source ~/.zshrc-modules/.zshrc.appearance
source ~/.zshrc-modules/.zshrc.vim-mode

#export PATH="$HOME/.pyenv/shims:$PATH"

# Custom man pages for dotfiles
export MANPATH="$HOME/dev/dotfiles/configs/man:$MANPATH"

# secrets
[[ -f ~/.zshrc-modules/.zshrc.sec ]] && source ~/.zshrc-modules/.zshrc.sec
[[ -f ~/.zshrc-sec ]] && source ~/.zshrc-sec

# Work mode: touch ~/.zshrc-work-mode to enable
if [[ -f ~/.zshrc-work-mode ]]; then
    [[ -f ~/.zshrc-modules/.zshrc.work ]] && source ~/.zshrc-modules/.zshrc.work
else
    [[ -f ~/.zshrc-modules/.zshrc.personal ]] && source ~/.zshrc-modules/.zshrc.personal
fi

export GPG_TTY=$TTY
export PATH="$HOME/.local/bin:$PATH"

# bun completions (BUN_INSTALL is exported in .zshrc.envvars; defaults to ~/.bun)
[ -s "${BUN_INSTALL:-$HOME/.bun}/_bun" ] && source "${BUN_INSTALL:-$HOME/.bun}/_bun"

# glr — "go latest release": fetch, switch to the highest release/X.Y.Z on
# origin, carrying any uncommitted changes (tracked + untracked) along via stash.
# When already on the latest release, rebase local commits onto origin (pull --rebase).
alias glr='() {
  git fetch origin --prune --quiet || { echo "glr: fetch failed" >&2; return 1 }
  local latest=$(git branch -r --list "origin/release/*" | sed "s@^[ *+]*origin/@@" | grep -E "^release/[0-9]+\.[0-9]+\.[0-9]+$" | sort -V | tail -1)
  [[ -z "$latest" ]] && { echo "glr: no release/X.Y.Z on origin" >&2; return 1 }
  if [[ "$(git symbolic-ref --quiet --short HEAD)" == "$latest" ]]; then
    local stashed=0
    if [[ -n "$(git status --porcelain)" ]]; then
      git stash push --include-untracked --message "glr auto-stash" && stashed=1
    fi
    if ! git rebase "origin/$latest"; then
      echo "glr: rebase onto origin/$latest hit conflicts — resolve & '"'"'git rebase --continue'"'"' (or '"'"'git rebase --abort'"'"')" >&2
      [[ $stashed == 1 ]] && echo "glr: your changes are safe in the stash — '"'"'git stash pop'"'"' once the rebase settles" >&2
      return 1
    fi
    if [[ $stashed == 1 ]]; then
      git stash pop || { echo "glr: stash pop conflicts — resolve, then git stash drop" >&2; return 1 }
      echo "glr: rebased $latest onto origin with your changes re-applied"
    else
      echo "glr: rebased $latest onto origin/$latest"
    fi
    return 0
  fi
  if git worktree list --porcelain | grep -q "^branch refs/heads/$latest$"; then
    echo "glr: $latest is checked out in another worktree:" >&2
    git worktree list | grep "\[$latest\]" | sed "s/^/       /" >&2
    echo "     cd there instead of switching here." >&2; return 1
  fi
  local stashed=0
  if [[ -n "$(git status --porcelain)" ]]; then
    git stash push --include-untracked --message "glr auto-stash" && stashed=1
  fi
  if ! git switch "$latest"; then
    echo "glr: switch failed" >&2
    [[ $stashed == 1 ]] && echo "glr: restore with: git stash pop" >&2
    return 1
  fi
  git merge --ff-only "origin/$latest" --quiet 2>/dev/null
  if [[ $stashed == 1 ]]; then
    git stash pop || { echo "glr: stash pop conflicts — resolve, then git stash drop" >&2; return 1 }
    echo "glr: on $latest with your changes re-applied"
  else
    echo "glr: on $latest (was clean)"
  fi
}'
