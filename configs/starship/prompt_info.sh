#!/bin/bash

# Get git repo root name, or fall back to current directory name
git_root=$(git rev-parse --show-toplevel 2>/dev/null)

if [ -n "$git_root" ]; then
  project=$(basename "$git_root")
  branch=$(git branch --show-current 2>/dev/null)

  # Show branch only if not on main or master
  if [ "$branch" = "main" ] || [ "$branch" = "master" ] || [ -z "$branch" ]; then
    echo "$project"
  else
    echo "$project $branch"
  fi
else
  echo "$(basename "$PWD")"
fi
