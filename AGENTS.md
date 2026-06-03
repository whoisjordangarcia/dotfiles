# Repository Guidelines

## Project Structure & Module Organization

This is a cross-platform dotfiles repository. Top-level entry points are `boot.sh`, `bootstrap.sh`, and `bin/dot`. Installation logic lives in `script/`, with shared helpers in `script/common/` and component installers under paths like `script/tmux/setup.sh` or `script/apps/mac/setup.sh`. Symlinked application settings live in `configs/`, grouped by tool or platform, for example `configs/nvim/`, `configs/hypr/`, `configs/rift/`, and `configs/waybar/`. Static assets and reference docs live in `art/`, `wallpapers/`, and `docs/`.

## Build, Test, and Development Commands

- `./bin/dot -i`: run the interactive installer.
- `./bin/dot -l`, `./bin/dot -s`, `./bin/dot -c`: list profiles, inspect system detection, and show current config.
- `./script/<component>/setup.sh`: run one component installer directly, such as `./script/zsh/setup.sh`.

## Coding Style & Naming Conventions

Shell scripts use Bash and should prefer `set -euo pipefail` for setup paths. Reuse `script/common/log.sh` and `script/common/symlink.sh` instead of duplicating logging or symlink behavior. Keep component paths lowercase and descriptive. Lua files under `configs/nvim/` are formatted by Stylua with 2-space indentation. Preserve application-native formatting for JSONC, YAML, TOML, and desktop config files.

## Testing Guidelines

For shell installers, prefer targeted smoke checks and avoid destructive runs against a real home directory; use `DOT_SYMLINK_MODE=skip` or `--dry-run` where supported.

## Commit & Pull Request Guidelines

Recent commits are short, lowercase summaries such as `make zshrc faster` and `tmux improvements`. Keep commits focused and mention the affected component when useful, for example `tmux: update pane title script`. Pull requests should describe the target platform/profile, list commands run, call out any generated or local-only files, and include screenshots for visible desktop, terminal, or window-manager changes.

## Agent-Specific Instructions

Do not run full install or package-management scripts unless explicitly requested. Do not overwrite `.dotconfig`, home-directory symlinks, or user-local machine settings while validating changes. Keep edits scoped to the requested component and preserve unrelated local modifications.
