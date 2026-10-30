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

`wt remove` and `wt prune` have no `--headless` flag: they go headless on their own when stdin or stderr isn't a TTY (an agent's shell). Headless `wt remove` requires a target (`wt remove <name>`) and exits 1 without one.

## Reviewing a PR — `wt review`

Run a PR (a teammate's, or your own to click through) in a persistent review slot instead of creating a worktree:

```bash
timeout 900 ~/.nest/bin/wt review --from-ci <pr>; echo "exit=$?"
```

- **Non-interactive as-is** under the `Bash` tool. Progress goes to stderr; stdout ends with the slot line, one `<app>  <url>` line per app plus `api`, and `total`. Exit 0 means the API booted and the frontends are being served.
- **Always pass `--from-ci`.** It downloads the frontends and API dist that `ci.yml` built for the PR head. Any app without an artifact builds locally, exactly as without the flag. Drafts, unaffected apps, CI still running, or a failed build all fall back this way. Each step line ends with `CI artifact` or `no CI artifact — building locally`. About 1.5 min with artifacts, about 3 min building locally on an idle machine.
- **Frontends served:** only the apps the PR's diff touches. Add `--all` for every app.
- **Verify in a browser, not just with curl.** Use agent-browser with the `nest-portal-sign-in` skill on the printed portal URL; its port comes from stdout, not from the worktree's stack env. Three things prove the slot works:
  - the bottom-right banner reads `<slot> · PR #<n> · <sha>`;
  - a data page (the patient list, then one patient) loads rows;
  - every GraphQL request goes to the slot's `api` port. Check with `performance.getEntriesByType('resource')`; a request to `:3000` means the static build's API address wasn't rewritten.

  Close the session afterwards with `agent-browser --session <name> close`.
- **Background it:** `--prepare <pr>` does everything except boot, so a later `wt review <pr>` skips the build but still boots the API. Add `--warm` to boot too; the later call then just prints the URLs.
- **Slots:** `--list` shows slots, PRs, ports and age. `--release <slot|pr>` frees a slot. Slots whose PR merged or closed are released automatically on any `wt review` call.
- **All slots full:** it exits with an error listing who holds each slot. A slot may be a review the user is using, so **ask before releasing one**, or raise `--slots <n>`.
- **`template DB is behind … run wt review --init-template`** is a warning, not a failure. The PR's pending migrations are applied to the clone anyway. Run `wt review --init-template` when convenient; it rebuilds the seeded template.
- It runs the PR's install scripts, build and API locally, so only run PRs you would run on this machine.
- The installed `~/.nest/bin/wt` is a snapshot. If a flag is missing from `wt review --help`, it predates the change: rebuild with `tools/stack/bin/install-worktree` from the main checkout.

## Why no pty wrapper

The TUI gate is `stdin.isTTY && stderr.isTTY`. `wt` already takes the headless path whenever either is false — which is the case under the agent `Bash` tool, CI, and piped stdin. So headless works as-is.

A pty makes both true and forces the TUI back on. On failure it parks on `Press any key to exit` waiting for a keypress that can never arrive, hides the real error behind that prompt, and leaves `zsh` + `script` as immortal orphans reparented to launchd. `< /dev/null` does not help: that redirects the wrapper's stdin while the child still inherits the pty slave.

## Husky in a new worktree

Run `pnpm exec husky` before your first commit.

`core.hooksPath` points at `.husky/_/`, which is gitignored and not created in new worktrees. When it's missing git silently skips every hook — lint-staged, prettier, eslint — and unformatted code lands on the branch and breaks CI.

Idempotent; also runs via `pnpm i` and `nx run doctor`. Verify: `test -f "$(git config --get core.hooksPath)/pre-commit" && echo ok`.

## Concurrency

Cap lint/test concurrency at 3 so the machine stays responsive:

```bash
turbo run lint --concurrency=3 --filter=<app>
turbo run test --concurrency=3 --filter=<app>
```
