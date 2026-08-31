# Nest worktrees (`wt`)

## Creating one non-interactively

Call the binary directly with `--headless`:

```bash
~/.nest/bin/wt create --headless NES-1234-my-fix release/X.Y.Z --setup install
```

- **The binary, not the shell function.** `wt` is a shell function that only `cd`s your interactive shell; that doesn't persist across a tool call.
- **Headless requires both `name` and a `release/X.Y.Z` base-ref** (never `main`). Missing either exits 1 with a usage error rather than prompting.
- The created path goes to stdout, terse progress to stderr.
- Default setup is full and slow. Use `--setup install` for deps + husky only, or background the full run and tail the log.
- Verify it exited rather than parked: `timeout 600 … ; echo "exit=$?"` (124 = hung).

`wt remove` and `wt prune` take the same `--headless` flag.

## Why no pty wrapper

The TUI gate is `stdin.isTTY && stderr.isTTY`. `wt` already takes the headless path whenever either is false — which is the case under the agent `Bash` tool, CI, and piped stdin. So headless works as-is.

A pty makes both true and forces the TUI back on. On failure it parks on `Press any key to exit` waiting for a keypress that can never arrive, hides the real error behind that prompt, and leaves `zsh` + `script` as immortal orphans reparented to launchd. `< /dev/null` does not help: that redirects the wrapper's stdin while the child still inherits the pty slave.

## Husky in a new worktree

Run `pnpm exec husky` before your first commit.

`core.hooksPath` points at `.husky/_/`, which is gitignored and not created in new worktrees. When it's missing git silently skips every hook — lint-staged, prettier, eslint — and unformatted code lands on the branch and breaks CI.

Idempotent; also runs via `pnpm i` and `nx run doctor`. Verify: `ls "$(git config --get core.hooksPath)/pre-commit"`.

## Concurrency

Cap lint/test concurrency at 3 so the machine stays responsive:

```bash
turbo run lint --concurrency=3 --filter=<app>
turbo run test --concurrency=3 --filter=<app>
```
