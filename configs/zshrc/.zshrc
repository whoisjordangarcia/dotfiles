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
export PATH="$HOME/.cargo/bin:$PATH" # cargo-installed tools (sonic-tui)

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

# _zmxrows — shared source of truth: one tab-separated row per session
# (fullname, short id, age, worktree), sorted by worktree. zmxls and zmxa
# both consume this so the row numbers you see match what you attach to.
_zmxrows() {
  zmx list | awk -v now="$(date +%s)" -F'\t' '
    /name=/ {
      full=""; id=""; age=0; dir=""
      for (i=1; i<=NF; i++) {
        if ($i ~ /name=/)           { s=$i; sub(/.*name=/,"",s);      full=s; id=substr(s,length(s)-7) }
        else if ($i ~ /created=/)   { s=$i; sub(/.*created=/,"",s);   age=now-s }
        else if ($i ~ /start_dir=/) { s=$i; sub(/.*start_dir=/,"",s); sub(/.*\//,"",s); dir=s }
      }
      a = age<3600 ? int(age/60)"m" : age<86400 ? int(age/3600)"h" : int(age/86400)"d"
      printf "%s\t%s\t%s\t%s\n", full, id, a, dir
    }' | sort -t$'\t' -k4
}

# zmxls — narrow `zmx list` for mobile: row#, short id, age, worktree.
zmxls() { _zmxrows | awk -F'\t' '{ printf "%3d  %-8s %4s  %s\n", NR, $2, $3, $4 }' }

# _zmxpick — resolve a session selector to a full session name on stdout.
#   `1` (digits)  → that row number from zmxls
#   `foo` (text)  → first session whose row matches the substring
#   (no arg)      → fzf pick, with a live scrollback preview (`zmx history`).
# $2 = "new" lets the fzf branch return a name you TYPE (Ctrl-N, or a query that
# matches nothing) so the caller can create it — attach passes this, kill/tail
# don't, so they only ever resolve existing sessions. Returns 1 if unresolved.
# Runs `zmx list` once (via _zmxrows); every zmx* helper below builds on this.
_zmxpick() {
  local rows n
  rows=$(_zmxrows)
  if [[ "$1" == <-> ]]; then                        # all-digits → row number
    n=$(sed -n "${1}p" <<<"$rows" | cut -f1)
    [[ -z "$n" ]] && { echo "zmx: no row $1" >&2; return 1 }
  elif [[ -n "$1" ]]; then                          # substring → match a name
    n=$(grep -- "$1" <<<"$rows" | head -1 | cut -f1)
    [[ -z "$n" ]] && { echo "zmx: no session matching $1" >&2; return 1 }
  else                                              # no arg → fzf pick
    local out query key sel
    out=$(awk -F'\t' '{ printf "%-8s %4s  %s\t%s\n", $2, $3, $4, $1 }' <<<"$rows" \
        | fzf --height=80% --reverse --with-nth=1 --delimiter=$'\t' \
              --print-query --expect=ctrl-n \
              --header='enter: pick · ctrl-n: new from query' \
              --preview='zmx history {2} 2>/dev/null | tail -300' \
              --preview-window=right:60%:follow)
    query=$(sed -n 1p <<<"$out"); key=$(sed -n 2p <<<"$out"); sel=$(sed -n 3p <<<"$out")
    if [[ -n "$2" && ( "$key" == ctrl-n || ( -z "$sel" && -n "$query" ) ) ]]; then
      n="$query"                                    # create-new: use the typed name
    elif [[ -n "$sel" ]]; then
      n=$(cut -f2 <<<"$sel")                         # picked an existing row
    else
      return 1                                       # escaped / nothing chosen
    fi
  fi
  print -r -- "$n"
}

# zmxa — attach by row #, substring, or fzf. In fzf, ctrl-n (or a query that
# matches nothing) creates a new session named after what you typed. `zmxa 1`.
zmxa() { local n; n=$(_zmxpick "$1" new) || return; zmx attach "$n" }

# zmxk — kill a session picked the same way, and echo which one went.
zmxk() { local n; n=$(_zmxpick "$1") || return; zmx kill "$n" && echo "killed $n" }

# zmxt — tail (follow live output of) a session picked the same way.
zmxt() { local n; n=$(_zmxpick "$1") || return; zmx tail "$n" }
