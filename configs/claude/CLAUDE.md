# Global instructions

## Obsidian notes (`~/dev/notes`)

Plain markdown in a git repo. Routing rule:

- **Text matching** (search, file ops, wikilinks, MOCs) → native file tools, `rg`/`Glob`. No app needed.
- **Obsidian metadata** (tasks, tags, backlinks, frontmatter/properties, orphans, link graph, `eval` scripting) → the `notes-cli` skill. Requires the Obsidian app running.

Daily notes go through the `daily-note` skill. The why is in `~/dev/notes/10 - Meta/Vault Tooling Decision.md`.

## Scope — surgical changes only

- **Fix the thing I asked about. Nothing else.** The request is the deliverable, not a starting point. Adjacent code looking improvable is not a reason to widen.
- **Build for today's caller.** No abstraction for a second caller that doesn't exist, no validation for input nobody sends, no config knob for a value that never changes, no "while I'm in here" refactor. Speculative hardening costs review surface and breakage.
- **The one exception is a real defect** — something producing wrong behaviour today, or on the next run of a known-live code path. A *hypothetical* failure is not a bug. Fix it if it's in the blast radius of what I'm already touching; otherwise name it and let me decide.
- **Root cause still beats symptom.** Surgical means narrow, not shallow. One guard in the shared function every caller routes through is surgical; the same guard copy-pasted into five callers is not. Understanding the whole flow before cutting is always in scope.
- **Unrelated findings become tickets, not diff.** Tell me what turned up and offer to file it. If I say yes, dispatch a subagent to create the Linear ticket so the write-up doesn't eat the context of the work in flight — give it the full finding: file and line, what's wrong, the evidence, how it was found. Ask before filing; file rather than fix.
- **When a fix has genuinely separable layers, name them and ask.** Default to shipping only the layer that fixes the reported problem.

## Comments — signal, not essays

- **Rationale goes in the commit message and PR body.** Why this design, what was rejected, the history, the precedent, the argument defending a trade-off — reviewers read those once. Inline they become a block every future reader scrolls past forever.
- **An inline comment earns its place by being short and load-bearing:** a non-obvious constraint, a gotcha, a "why this and not the obvious thing", in one or two lines. Longer than the code it describes means cut it.
- **One-line summaries only** on files, classes, functions, and Terraform resources — the bit that isn't inferable from the code.
- Cut the prose, keep the signal: the constraint, the units, the ceiling, the link to a rule file.
