#!/bin/bash
# Combined prompt info: repo/worktree name + conditional branch.
# Avoid git subprocesses in prompt rendering so starship stays under its
# command_timeout budget even in large repos or when git is briefly locked.

find_git_root() {
  local dir=$PWD

  while [ "$dir" != "/" ]; do
    if [ -e "$dir/.git" ]; then
      printf '%s' "$dir"
      return 0
    fi
    dir=${dir%/*}
    [ -n "$dir" ] || dir="/"
  done

  return 1
}

resolve_gitdir() {
  local root=$1
  local gitdir=$root/.git
  local value base

  if [ -f "$gitdir" ]; then
    IFS= read -r value < "$gitdir"
    value=${value#gitdir: }
    if [[ "$value" = /* ]]; then
      gitdir=$value
    else
      base=$(cd "$root" 2>/dev/null && cd "${value%/*}" 2>/dev/null && pwd -P)
      gitdir="$base/${value##*/}"
    fi
  fi

  printf '%s' "$gitdir"
}

read_branch() {
  local gitdir=$1
  local head

  [ -r "$gitdir/HEAD" ] || return 1
  IFS= read -r head < "$gitdir/HEAD"

  case "$head" in
    "ref: refs/heads/"*) printf '%s' "${head#ref: refs/heads/}" ;;
    "ref: "*) printf '%s' "${head#ref: }" ;;
    *) return 1 ;;
  esac
}

# GitHub PR indicator. `gh pr view` is a network round-trip an order of
# magnitude over starship's command_timeout, so the prompt only ever reads a
# cache file and kicks off a detached refresh when it goes stale.
PR_TTL=300
PR_CACHE_DIR=${XDG_CACHE_HOME:-$HOME/.cache}/starship-pr

pr_part() {
  local branch=$1 root=$2
  local file="$PR_CACHE_DIR/${root//\//_}__${branch//\//_}"
  local now=${EPOCHSECONDS:-$(date +%s)}
  local stamp='' state='' num='' url='' stale=1

  [ -r "$file" ] && IFS=$'\t' read -r stamp state num url < "$file"

  case "$stamp" in
    '' | *[!0-9]*) stale=1 ;;
    *) [ $((now - stamp)) -ge "$PR_TTL" ] && stale=1 || stale=0 ;;
  esac

  if [ "$stale" = 1 ]; then
    [ -d "$PR_CACHE_DIR" ] || mkdir -p "$PR_CACHE_DIR"
    # Bump the clock *before* forking so a burst of prompts doesn't fan out
    # one `gh` process each.
    printf '%s\t%s\t%s\t%s\n' "$now" "$state" "$num" "$url" > "$file"
    # stdout MUST be detached: starship reads this script's stdout until EOF,
    # and a background job inheriting the pipe would hold it open for the whole
    # gh round-trip — turning the "async" refresh into a synchronous stall.
    (
      info=$(gh pr view --json state,isDraft,number,url \
        --jq '(if .isDraft then "DRAFT" else .state end) + "\t" + (.number|tostring) + "\t" + .url' 2>/dev/null) ||
        info=$'NONE\t\t'
      printf '%s\t%s\n' "$now" "$info" > "$file"
    ) > /dev/null 2>&1 &
  fi

  [ -n "$num" ] || return 0

  local color glyph
  case "$state" in
    OPEN) color=32 glyph='●' ;;
    DRAFT) color=90 glyph='○' ;;
    MERGED) color=35 glyph='⬥' ;;
    CLOSED) color=31 glyph='✕' ;;
    *) return 0 ;;
  esac

  # Trailing \033[1;36m restores the module's `bold cyan` for the branch text.
  #
  # \001<url>\002 … \003 are rewritten into an OSC 8 hyperlink by
  # _starship_pr_hyperlink (.zshrc.init), which also exports STARSHIP_PR_LINK.
  # Emitting OSC 8 here instead would be mangled: starship's zsh escaper closes
  # its %{…%} region mid-URL, leaking the URL tail into zsh's visible-width
  # count. Without the hook the sentinels are invisible control chars and the
  # bare URL would render as prompt text, so only emit them when it's live.
  if [ -n "${STARSHIP_PR_LINK:-}" ]; then
    printf '\001%s\002\033[%sm%s#%s\033[1;36m\003 ' "$url" "$color" "$glyph" "$num"
  else
    printf '\033[%sm%s#%s\033[1;36m ' "$color" "$glyph" "$num"
  fi
}

[ -n "${PROMPT_INFO_LIB:-}" ] && return 0

if root=$(find_git_root); then
  gitdir=$(resolve_gitdir "$root")
  prefix=${PWD#"$root"}
  prefix=${prefix#/}

  if [[ "$gitdir" == */worktrees/* ]]; then
    name=${gitdir##*/}
    dir_part=$(printf '\xef\x81\xac  %s' "$name")
  else
    name=${root##*/}
    if [ -n "$prefix" ]; then
      dir_part="${name}/${prefix}"
    else
      dir_part="$name"
    fi
  fi

  if branch=$(read_branch "$gitdir"); then
    pr_part "$branch" "$root"
    norm_name=${name//\//-}
    norm_br=${branch//\//-}
    # Worktree dirs are slugified branch names (slashes -> dashes, often
    # lowercased), so compare case-insensitively. nocasematch (bash 3.1+)
    # avoids ${var,,} which needs bash 4 (macOS ships 3.2).
    shopt -s nocasematch
    # Worktree name equal to branch OR a suffix of it (e.g. branch
    # "chris/foo" + worktree "foo") -> redundant, show only the branch
    if [[ "$gitdir" == */worktrees/* ]] &&
      { [[ "$norm_name" == "$norm_br" ]] || [[ "$norm_br" == *"$norm_name" ]]; }; then
      printf '\xef\x81\xac  %s' "$branch"
    else
      printf '%s %s' "$dir_part" "$branch"
    fi
  else
    printf '%s' "$dir_part"
  fi
else
  printf '%s\n' "${PWD##*/}"
fi
