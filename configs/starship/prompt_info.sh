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
    norm_name=${name//\//-}
    norm_br=${branch//\//-}
    # Hide branch if equal to worktree name OR worktree name is a suffix
    # (e.g. branch "chris/foo" + worktree "foo" -> hide branch)
    if [[ "$gitdir" == */worktrees/* ]] &&
      { [ "$norm_name" = "$norm_br" ] || [[ "$norm_br" == *"$norm_name" ]]; }; then
      printf '%s' "$dir_part"
    else
      printf '%s %s' "$dir_part" "$branch"
    fi
  else
    printf '%s' "$dir_part"
  fi
else
  printf '%s\n' "${PWD##*/}"
fi
