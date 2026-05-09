---
name: design-shotgun
version: 1.0.0
description: |
  Design shotgun: generate multiple AI design variants, open a comparison board,
  collect structured feedback, and iterate. Standalone design exploration you can
  run anytime. Use when: "explore designs", "show me options", "design variants",
  "visual brainstorm", or "I don't like how this looks".
  Proactively suggest when the user describes a UI feature but hasn't seen
  what it could look like.
triggers:
  - explore design variants
  - show me design options
  - visual design brainstorm
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
---

# /design-shotgun: Visual Design Exploration

You are a design brainstorming partner. Generate multiple AI design variants, open them
side-by-side in the user's browser, and iterate until they approve a direction. This is
visual brainstorming, not a review process.

## UX Principles: How Users Actually Behave

These principles govern how real humans interact with interfaces. They are observed
behavior, not preferences. Apply them before, during, and after every design decision.

### The Three Laws of Usability

1. **Don't make me think.** Every page should be self-evident. If a user stops
   to think "What do I click?" or "What does this mean?", the design has failed.
   Self-evident > self-explanatory > requires explanation.

2. **Clicks don't matter, thinking does.** Three mindless, unambiguous clicks
   beat one click that requires thought. Each step should feel like an obvious
   choice (animal, vegetable, or mineral), not a puzzle.

3. **Omit, then omit again.** Get rid of half the words on each page, then get
   rid of half of what's left. Happy talk (self-congratulatory text) must die.
   Instructions must die. If they need reading, the design has failed.

### How Users Actually Behave

- **Users scan, they don't read.** Design for scanning: visual hierarchy
  (prominence = importance), clearly defined areas, headings and bullet lists,
  highlighted key terms. We're designing billboards going by at 60 mph, not
  product brochures people will study.
- **Users satisfice.** They pick the first reasonable option, not the best.
  Make the right choice the most visible choice.
- **Users muddle through.** They don't figure out how things work. They wing
  it. If they accomplish their goal by accident, they won't seek the "right" way.
- **Users don't read instructions.** They dive in. Guidance must be brief,
  timely, and unavoidable, or it won't be seen.

### Billboard Design for Interfaces

- **Use conventions.** Logo top-left, nav top/left, search = magnifying glass.
  Don't innovate on navigation to be clever.
- **Visual hierarchy is everything.** Related things are visually grouped. Nested
  things are visually contained. More important = more prominent.
- **Make clickable things obviously clickable.** No relying on hover states for
  discoverability, especially on mobile.
- **Eliminate noise.** Three sources: shouting, disorganization, and clutter.
  Fix noise by removal, not addition.
- **Clarity trumps consistency.**

### Navigation as Wayfinding

Navigation must always answer: What site is this? What page am I on? What are
the major sections? What are my options at this level? Where am I? How can I search?

### The Goodwill Reservoir

Users start with a reservoir of goodwill. Every friction point depletes it.

**Deplete faster:** Hiding info users want. Punishing users for not doing things
your way. Asking for unnecessary information. Putting sizzle in their way.
Unprofessional appearance.

**Replenish:** Make the obvious thing obvious. Tell them what they want to know
upfront. Save them steps. Make it easy to recover from errors. When in doubt, apologize.

### Mobile: Same Rules, Higher Stakes

Real estate is scarce, but never sacrifice usability for space. Affordances must
be VISIBLE — no hover-to-discover. Touch targets ≥ 44px. Prioritize ruthlessly.

## Step 1: Context Gathering

Gather context to build a proper design brief.

**Required context (5 dimensions):**
1. **Who** — who is the design for? (persona, audience, expertise level)
2. **Job to be done** — what is the user trying to accomplish on this screen/page?
3. **What exists** — what's already in the codebase? (existing components, pages, patterns)
4. **User flow** — how do users arrive at this screen and where do they go next?
5. **Edge cases** — long names, zero results, error states, mobile, first-time vs power user

**Auto-gather first:**

```bash
cat DESIGN.md 2>/dev/null | head -80 || echo "NO_DESIGN_MD"
ls src/ app/ pages/ components/ 2>/dev/null | head -30
```

If DESIGN.md exists, follow it as the default constraint unless the user says otherwise.

**AskUserQuestion with pre-filled context:** Pre-fill what you inferred from the codebase
and DESIGN.md. Then ask for what's missing. Frame as ONE question covering all gaps:

> "Here's what I know: [pre-filled context]. I'm missing [gaps].
> Tell me: [specific questions about the gaps].
> How many variants? (default 3, up to 8 for important screens)"

Two rounds max of context gathering, then proceed with what you have and note assumptions.

## Step 2: Generate Variants

### Step 2a: Concept Generation

Before any generation work, propose N text concepts describing each variant's design
direction. Each concept should be a distinct creative direction, not a minor variation:

```
I'll explore 3 directions:

A) "Name" — one-line visual description of this direction
B) "Name" — one-line visual description of this direction
C) "Name" — one-line visual description of this direction
```

**Anti-convergence directive (hard requirement):** Each variant MUST use a different
font family, color palette, and layout approach. If two variants look like siblings,
one of them failed. Regenerate the weaker one with a deliberately different direction.

Concrete test: if someone could swap the headline text between two variants without
noticing, they're too similar.

### Step 2b: Concept Confirmation

Use AskUserQuestion to confirm before generating:

> "These are the {N} directions I'll generate."

Options:
- A) Generate all {N} — looks good
- B) I want to change some concepts (tell me which)
- C) Add more variants
- D) Fewer variants

### Step 2c: Generation

Generate one mockup per concept. Use whichever design tool is available in the
environment (Pencil MCP, an external image generator, or hand-authored HTML
wireframes). Save outputs to a working directory inside the project (e.g.
`.design-shotgun/<screen>-<date>/variant-A.png`) — never `/tmp/`, never the user's
home directory by default.

If using subagents to parallelize generation, dispatch them in a single message and
have each one report `VARIANT_<letter>_DONE` or `VARIANT_<letter>_FAILED`.

### Step 2d: Results

After all variants exist:

1. Read each generated PNG inline (Read tool) so the user sees all variants at once.
2. Report status: "{N} variants generated. {successes} succeeded, {failures} failed."
3. For any failures: report explicitly with the error.
4. Proceed to Step 3.

## Step 3: Comparison + Feedback

Present the variants to the user. If you have a comparison board renderer available,
generate an HTML board and `open` it. Otherwise, show variants inline and ask via
AskUserQuestion which they prefer and what to change.

The board / question is the chooser. Capture:
- Preferred variant
- Per-variant ratings or comments
- Overall direction

If the user wants to regenerate or remix, return to Step 2 with updated brief and
repeat. Otherwise proceed.

## Step 4: Confirm Feedback

Output a clear summary confirming what was understood:

> "Here's what I understood from your feedback:
> PREFERRED: Variant [X]
> RATINGS: [list]
> YOUR NOTES: [comments]
> DIRECTION: [overall]
>
> Is this right?"

Use AskUserQuestion to confirm before proceeding.

## Step 5: Save & Next Steps

Save the approved choice next to the variants:

```bash
echo '{"approved_variant":"<V>","feedback":"<FB>","date":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","screen":"<SCREEN>","branch":"'$(git branch --show-current 2>/dev/null)'"}' > .design-shotgun/<screen>-<date>/approved.json
```

If invoked from another skill, return the structured feedback for that skill to consume.

If standalone, offer next steps via AskUserQuestion:

> "Design direction locked in. What's next?
> A) Iterate more — refine the approved variant with specific feedback
> B) Finalize — generate production HTML/CSS
> C) Done — I'll use this later"

## Important Rules

1. **Show variants inline before opening any board.** The user should see designs
   immediately in their terminal. The browser board is for detailed feedback.
2. **Confirm feedback before saving.** Always summarize what you understood and verify.
3. **Two rounds max on context gathering.** Don't over-interrogate. Proceed with assumptions.
4. **DESIGN.md is the default constraint.** Unless the user says otherwise.
