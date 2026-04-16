#!/bin/bash
# Combined prompt info: repo/worktree name + conditional branch.
# One script per prompt render; keeps subprocess forks minimal so starship
# stays under its command_timeout budget.

if [ -f .git ]; then
  # Worktree: .git is a file pointing at the real gitdir
  read -r _ wt_path < .git
  wt_name=${wt_path##*/}
  dir_part=$(printf '\xef\x81\xac  %s' "$wt_name")
  branch=$(git branch --show-current 2>/dev/null)
  if [ -n "$branch" ]; then
    # Bash native substitution — avoids echo|tr subprocess forks
    norm_wt=${wt_name//\//-}
    norm_br=${branch//\//-}
    # Hide branch if equal to worktree name OR worktree name is a suffix
    # (e.g. branch "chris/foo" + worktree "foo" → hide branch)
    if [ "$norm_wt" != "$norm_br" ] && [[ "$norm_br" != *"$norm_wt" ]]; then
      printf '%s %s' "$dir_part" "$branch"
    else
      printf '%s' "$dir_part"
    fi
  else
    printf '%s' "$dir_part"
  fi
elif git_info=$(git rev-parse --show-toplevel --show-prefix 2>/dev/null); then
  # Regular repo — one git call instead of two for toplevel + prefix
  { IFS= read -r toplevel; IFS= read -r prefix; } <<< "$git_info"
  root=${toplevel##*/}
  if [ -n "$prefix" ]; then
    dir_part="${root}/${prefix%/}"
  else
    dir_part="$root"
  fi
  branch=$(git branch --show-current 2>/dev/null)
  if [ -n "$branch" ]; then
    printf '%s %s' "$dir_part" "$branch"
  else
    printf '%s' "$dir_part"
  fi
else
  echo "${PWD##*/}"
fi
