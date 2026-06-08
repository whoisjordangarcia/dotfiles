if [[ -n "$SSH_CONNECTION" ]]; then export TERM=xterm-256color; fi

source_files() {
    for config_file in "$@"; do
        if [[ -f "$config_file" ]]; then
            echo "Loading $config_file"
            source "$config_file"
            return 0
        fi
    done
    return 1
}

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

# bun completions
[ -s "/home/jordan/.bun/_bun" ] && source "/home/jordan/.bun/_bun"

alias claude-mem='bun "/Users/nest/.claude/plugins/cache/thedotmack/claude-mem/12.1.3/scripts/worker-service.cjs"'

# ── Turborepo (local dev) ──────────────────────────────────────────────
export TURBO_TELEMETRY_DISABLED=1    # no turbo usage telemetry
export DO_NOT_TRACK=1                # broader opt-out turbo (and other tools) honor
export TURBO_NO_UPDATE_NOTIFIER=1    # no "update available" nag in output
export TURBO_LOG_ORDER=grouped       # group each task's logs instead of interleaving

# Test concurrency, paired with the --maxWorkers=50% in the app test scripts:
# at most 2 test tasks overlap, each using ~half the cores → ~100% utilization,
# no oversubscription. NOTE: this is GLOBAL — it also caps build/lint/check-types.
# If full `turbo run build` feels slow, comment this out or override per-command
# with `--concurrency=10`.
export TURBO_CONCURRENCY=2

# Interactive turbo TUI on demand. Uses the --ui flag (beats turbo.json's
# "ui": "stream"; the TURBO_UI env var can be shadowed by that config).
# Needs a real TTY; best seen on real work (build/dev), not cached runs.
# Usage: turbo-tui run build
turbo-tui() { pnpm exec turbo "$@" --ui=tui; }

# Run turbo scoped to what changed since the release branch you forked from.
# Auto-detects the base: the origin/release/* whose merge-base with HEAD is newest
# (= the fork point). Falls back to origin/main. Usage: turbo-affected run test
turbo-affected() {
  local ref mb ts best=0 base=""
  for ref in $(git for-each-ref --format='%(refname:short)' 'refs/remotes/origin/release/*' 2>/dev/null); do
    mb=$(git merge-base HEAD "$ref" 2>/dev/null) || continue
    ts=$(git show -s --format=%ct "$mb" 2>/dev/null) || continue
    (( ts > best )) && { best=$ts; base=$mb }
  done
  : ${base:=origin/main}
  print -u2 "▸ turbo --affected base: ${base:0:12}"
  TURBO_SCM_BASE="$base" pnpm exec turbo run "$@" --affected
}
