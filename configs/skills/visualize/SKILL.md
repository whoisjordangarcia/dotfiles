---
name: visualize
description: Explain a code change step by step as a self-contained HTML stepper, before vs after drawn side by side on one concrete scenario.
disable-model-invocation: true
argument-hint: "[PR number | branch | commit range | path]"
---

# Visualize

Turn a code change into a stepper: one concrete **scenario** traced through the changed code, one stage per step, the old and new behaviour drawn side by side. A reader who clicks Next through every step understands the change without opening the diff.

## Steps

1. **Resolve the change** from `$ARGUMENTS`:
   - PR number → `gh pr diff <n>` and `gh pr view <n> --json title,body,baseRefName`
   - branch or range → `git diff <base>...<head>`
   - path → the working-tree diff of that path
   - empty → uncommitted changes plus the branch's diff against its base (infer the base the way the repo's `CLAUDE.md` says; else the default branch)

   Done when you have read every changed function end to end, plus the callers that feed it.

2. **Pick the scenario.** Name in one sentence the input → output the change alters ("the slot height reserved for an unmeasured row"). Choose one concrete input, using real names and values from the code, where before and after diverge. **Trace** it through both versions. Done when every value you will show is written as arithmetic from the code (`min(650, 1000 − 2·24 − 2·17) = 650`); each number is computed, never estimated.

3. **Plan 4–8 steps**, one per stage of the computation in execution order. Each step changes one thing in the visual; the last lands on the visible outcome: the bug gone, or the number that matters. Panes default to `before` / `after`; use another pair (two inputs, two modes) when it tells the change better.

4. **Build.** Copy [`template.html`](template.html) to `~/.cache/visualize/<slug>.html` and replace the object between `/*DECK*/` and `/*END*/`. The template's example deck shows every CSS primitive in use.

   | Field | Content |
   |---|---|
   | `title` | The whole comparison, constant across steps: "Cold open at the bottom: constant estimate vs width-aware" |
   | `steps[].label` | Short noun for the stage: "the width", "the chrome" |
   | `steps[].head` | The expression this step evaluates, with the scenario's arguments: `withChromePx(estimate, chromePx(row))` |
   | `steps[].items` | 2–4 lines of `<code>name</code> : value · why`. Add `class="hot"` to the `<code>` that changed this step |
   | `steps[].panes` | One `{name, html, foot}` per side. `html` draws what the code manipulates (rows, blocks, a queue, a timeline) **to scale** when size is the point. `foot` carries the totals: "total 1788 px · 11 rows mounted" |
   | `steps[].caption` | 1–2 plain sentences: what this stage does and why it matters. Reads on its own |

   Mark only what the current step changed with `hot` / `fill`; everything else stays neutral, so the eye lands on the delta.

   Steps **morph** into each other: a `.box` or `.thumb` that appears in consecutive steps glides to its new size and position, a new one pops in, and a missing one fades out. Write each step's `html` as the full state, not a diff. A box keeps its identity by its label with the digits stripped, matched in order, so `prose 80` → `prose 120` morphs on its own. Set `data-k` when the label changes otherwise or the box is empty (`fill` blocks). Numbers in `foot` count up to their new value when both steps' foot texts contain the same number of numbers, so keep each foot's wording the same from step to step.

5. **Verify.** Parse-check the script, then open it:
   ```bash
   f=~/.cache/visualize/<slug>.html
   sed -n '/<script>/,/<\/script>/p' "$f" | sed '1d;$d' > /tmp/visualize-check.js && node --check /tmp/visualize-check.js && open "$f"
   ```
   Done when `node --check` exits 0 and the file is open. Reply with the path and the scenario in one line.
