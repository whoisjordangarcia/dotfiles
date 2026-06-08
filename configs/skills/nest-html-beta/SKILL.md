---
name: nest-html-beta
version: 0.12.0
description: Use when the user asks for a shareable Nest-branded HTML doc, team write-up, summary page, slide deck, decision deck, presentation, S3 docs upload/update, docs index regeneration, or interactive HTML treatment using Mermaid, D3, ag-Grid, or three.js/WebGL.
---

## Preamble (run first)

```bash
# Telemetry is fire-and-forget: this block must never fail the caller,
# even under `set -euo pipefail`, outside a git repo, or before ~/.nest
# has been created. All failures are swallowed by the outer guard.
{
  mkdir -p ~/.nest/skill-analytics 2>/dev/null || true
  _AGENT="unknown"
  if [ "${CLAUDECODE:-}" = "1" ]; then
    _AGENT="claude-code"
  elif [ -n "${CURSOR_AGENT:-}" ]; then
    # Cursor sets CURSOR_AGENT during Agent (AI) sessions. See cursor.com/docs.
    _AGENT="cursor"
  elif [ -n "${CODEX_AGENT:-}" ] || [ -n "${CODEX_HOME:-}" ]; then
    # Codex does not publish a built-in 'I am running' env var. Users who
    # want reliable Codex attribution should add CODEX_AGENT=1 to their
    # ~/.codex/config.toml [shell_environment_policy].set table.
    _AGENT="codex"
  fi
  _BRANCH="$(git branch --show-current 2>/dev/null | tr -d '"\\' | head -c 100 || true)"
  if [ -z "$_BRANCH" ]; then _BRANCH="none"; fi
  printf '{"v":2,"skill":"nest-html-beta","version":"0.12.0","agent":"%s","ts":"%s","branch":"%s"}\n' \
    "$_AGENT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_BRANCH" \
    >> ~/.nest/skill-analytics/skill-usage.jsonl 2>/dev/null || true
} 2>/dev/null || true
```

# Team Summary HTML (beta)

> **Beta:** This is `nest-html-beta`, a personal/experimental copy of `nest-summary-html` living in `~/.claude/skills/`. Changes here are for trying things out and do not affect the published `nest-summary-html` plugin.

Produce a single, self-contained `.html` file for sharing with teammates, styled to match the Nest Genomics brand (Instrument Serif headings with an orange→purple gradient, white background, `#e65732` accent). Most requests become either a **long-form doc** or a **slide deck**; either format can use the full component palette: Mermaid diagrams, D3/SVG charts, ag-Grid tables, scrollytelling, stylized heroes, and three.js scenes.

## When to Use

- User wants to share a summary, recap, investigation, or brief with other people
- User explicitly asks for HTML output (not markdown)
- User says: "summarize for the team", "make it shareable", "write it up as a page", "html summary", "make a deck", or "presentation"

**Not for:** in-terminal summaries, markdown docs, or anything checked into a codebase as source.

## Design Tokens (nestgenomics.com)

Do not change these — this IS the skill.

| Token | Value |
|---|---|
| Heading font | `"Instrument Serif", Georgia, serif` (weight 400, Google Fonts) |
| Body font | `-apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif` |
| Background | `#ffffff` |
| Text | `#0a0a0a` |
| Secondary text | `rgba(10, 10, 10, 0.65)` |
| Brand orange (primary accent) | `#e65732` |
| Gradient mid | `#e78d32` |
| Gradient end (purple) | `#a367c8` |
| Rose | `#c45567` |
| Peach (button bg) | `#fadfd8` / hover `#f5cfc5` |
| Tan (card bg) | `#f5d1ad` |
| Border | `rgba(230, 87, 50, 0.18)` |
| Hover tint | `rgba(230, 87, 50, 0.06)` |
| Max content width | `720px` |
| Heading scale | H1 `clamp(48px, 7vw, 88px)`, H2 `clamp(32px, 4vw, 44px)`, H3 `18px` |
| Body size | `17px / 1.6` |

H1 uses a **linear-gradient** from `#e65732 → #e78d32 → #a367c8` clipped to text — this is the signature Nest move. Do not replace it with a solid color. Body headings (H2) stay solid `--ink`. Plenty of vertical whitespace; headings are sentence case, never uppercased.

## Workflow

1. **Ask the user up front: long-form doc, slide deck, or both?** *"Want this as a long-form HTML doc, a slide deck, or both? (Both generates two files — same content, two formats.)"* Defaults if no preference: long-form for plans/write-ups/investigations, deck for decision meetings/exec reviews/stand-up walkthroughs. If both, generate `<slug>.html` (long-form) and `<slug>-deck.html` (deck) from the same content.
2. Ask the user where to save the file if not specified — default to `~/Desktop/<slug>.html` (and `~/Desktop/<slug>-deck.html` if both).
3. Read the appropriate template:
   - **Long-form** → `template.html` — fill `{{TITLE}}`, `{{SUBTITLE}}`, `{{DATE}}`, `{{CONTENT}}`.
   - **Slide deck** → `slides-template.html` — fill `{{TITLE}}`, `{{EYEBROW}}`, `{{SUBTITLE}}`, `{{DATE}}`, `{{AUTHOR}}`, `{{SLIDES}}`, `{{FOOTER_LEFT}}`. Read `deck-format.md` for slide structure and wiring.
4. Write the result to disk. Do not introduce new CSS files, build steps, or external assets beyond the Google Fonts `<link>` already in the template. The only sanctioned CDN exceptions are **mermaid** (diagrams), **D3** (interactive charts), **ag-Grid** (interactive tables), **three.js** (3D scenes), and **highlight.js** (code syntax highlighting) — each only when the doc actually uses that capability.
5. Tell the user the absolute path and suggest `open <path>` to preview it.
6. **Ask the user if they want to upload/update the file to S3** to share it within the Nest team. If yes, upload to the `yoda-app-origin-tst` bucket under `nest-docs/` using the `tst-account-administrator-role` AWS profile, then report the Tailscale-gated URL: `https://tst.yoda.nestgenomics.com/nest-docs/<filename>.html` (only reachable from the Nest Tailscale network). If both formats were generated, upload both — both URLs go in the report.

## Example Loading Protocol

The examples are part of the skill, not optional inspiration. They are a component palette for the two normal output modes: **long-form docs** and **slide decks**. Do not treat examples as separate deliverable types.

Before writing output:

1. Choose the format: long-form, deck, or both.
2. Run a **visual/component pass** over the content. Look for numbers, flows, tables, concept networks, timelines, request traces, hero moments, and step-by-step narratives.
3. Match those shapes against **Match the content to a treatment** below.
4. If the right example is not obvious, read `examples/README.md` first for the quick map.
5. Read every example file referenced by the matching treatment rows before copying or adapting that treatment.
6. If the output is a substantial long-form doc or deck, do not stop at prose. Include the strongest fitting visual/component treatment unless the content is genuinely too small.
7. If the user asks for an ambitious/flagship doc, a visual showcase, "use the examples", or an interactive deck, read `examples/README.md`, then read all eight examples so the full palette is available.
8. Copy proven scaffolds from the examples and adapt only the data/content. Do not rewrite controllers, mount/dispose loops, chart builders, table theming, or WebGL setup from memory.

Use these exact one-level paths from this skill directory:

| Example | Use when |
|---|---|
| `examples/README.md` | Quick manifest for choosing which example to open and what to copy from it. |
| `examples/mermaid-and-charts-gallery.html` | Mermaid diagrams, simple SVG chart patterns, diagram/chart selection. |
| `examples/d3-chart-catalog.html` | Interactive D3 charts, animated charts, donut charts, hoverable quantitative views. |
| `examples/table-aggrid.html` | Default table treatment for authored tabular data; sortable/filterable/resizable, token-driven, and dark-mode aware. |
| `examples/longform-scrollytelling.html` | Long-form scroll-mounted figures, scrollytelling, scroll-driven scene state. |
| `examples/deck-scenes-and-features.html` | Deck scene mounting, `data-step`, presenter mode, build/reveal bullets, live JSON charts, confetti. |
| `examples/threejs-scene-gallery.html` | Ambient particles, point clouds, arc networks, request traces, globe arcs, morphs, timeline ribbons. |
| `examples/interactive-constellation.html` | Hover/click/pin concept graphs with context panels and center/zoom behavior. |
| `examples/threejs-stylized-renders.html` | Editorial hero visuals: mesh gradients, toon, halftone, riso, pixelated/outlined renders. |

## Reference Files (read as needed)

Read these direct support files before implementing their capability. They contain the detailed patterns that used to live in this file.

| Need | Read |
|---|---|
| Upload to S3, update an existing doc, or regenerate the docs index | `sharing-and-index.md` |
| Long-form page chrome, settings panel behavior, TOC, anchors, code blocks | `page-features.md` |
| Deck layout, slide patterns, navigation, print-to-PDF, presenter mode | `deck-format.md` |
| Mermaid diagrams or simple inline SVG charts | `mermaid-and-svg.md` |
| Interactive D3 charts or ag-Grid tables | `d3-and-tables.md` |
| three.js scenes, WebGL scaffolds, scrollytelling, stylized heroes | `threejs-scenes.md` |

## Content Rules

- Lead with the answer/TL;DR in a `<p class="lede">` directly under the title.
- Use `<h2>` for major sections, `<h3>` sparingly.
- Key numbers or short highlights can be wrapped in `<span class="accent">` to pick up the brand orange (`--accent`).
- Keep it scannable: short paragraphs, bulleted lists, bolded key terms.
- No emojis unless the user explicitly asks for them.

## Match the content to a treatment (do this BEFORE writing)

A wall of prose is the failure mode. Most Nest docs have a *shape* — a flow, a hierarchy, a story, a comparison, a hero moment — and this skill ships a treatment for each. **Scan the content against this table first and reach for the match;** don't default to text + maybe one chart. The 3D / scrollytelling / stylized treatments are **not** "beta, use rarely" — they're the intended tool when the content fits. The only hard rule: 3D is for relationships and space, never for reading exact numbers (those are SVG/D3 charts).

| If the content has… | Reach for | Read |
|---|---|---|
| numbers to compare, a distribution, parts-of-a-whole | **SVG or D3 chart** | `d3-and-tables.md`, `mermaid-and-svg.md`, `examples/d3-chart-catalog.html`, `examples/mermaid-and-charts-gallery.html` |
| components and how they connect; a flow, sequence, or lifecycle | **Mermaid diagram** | `mermaid-and-svg.md`, `examples/mermaid-and-charts-gallery.html` |
| tabular data, rows/columns, inventories, comparisons, recommendations, audit results, issue lists, cost/resource tables | **ag-Grid table by default** | `d3-and-tables.md`, `examples/table-aggrid.html` |
| **a narrative that unfolds step-by-step** — walking through a system, a data story, a "how it works" | **Scrollytelling** — a pinned scene that advances as the reader scrolls past prose | `threejs-scenes.md`, `examples/longform-scrollytelling.html` |
| **a title / hero / section divider wanting atmosphere or an editorial "wow"** — exec brief, decision deck, launch recap | **Stylized render** (mesh-gradient backdrop, toon, halftone, riso) or **ambient particle backdrop** | `threejs-scenes.md`, `examples/threejs-stylized-renders.html`, `examples/threejs-scene-gallery.html` |
| a web of related concepts where the connections are the point | **Interactive constellation** | `threejs-scenes.md`, `examples/interactive-constellation.html` |
| clusters / embeddings / 3-axis data | 3D point cloud | `threejs-scenes.md`, `examples/threejs-scene-gallery.html` |
| a request / integration flow with direction | arc network or request-trace | `threejs-scenes.md`, `examples/threejs-scene-gallery.html`, `examples/deck-scenes-and-features.html` |
| sites / vendors / regions | globe with arcs | `threejs-scenes.md`, `examples/threejs-scene-gallery.html`, `examples/deck-scenes-and-features.html` |
| before → after a migration | morphing point cloud | `threejs-scenes.md`, `examples/threejs-scene-gallery.html`, `examples/deck-scenes-and-features.html` |
| releases / milestones over time | timeline ribbon (3D) or a Gantt/timeline mermaid | `threejs-scenes.md`, `mermaid-and-svg.md`, `examples/threejs-scene-gallery.html`, `examples/deck-scenes-and-features.html`, `examples/mermaid-and-charts-gallery.html` |

**Calibration — match ambition to the doc, and actually reach:**
- Nearly every doc longer than a screen deserves **at least one** diagram, chart, or scene. A pure-text doc usually means a shape was missed — re-scan before shipping.
- **Investigations, "how it works" explainers, and decision/exec/launch docs should reach further** — a **scrollytelling** walkthrough or a **stylized hero**, not just a flowchart. These are exactly the docs where the richer treatments earn their place, and they're currently under-used.
- A quick status update stays lean; a flagship write-up earns a scene.
- When two treatments fit, prefer the simpler / more self-contained (SVG over D3, mermaid over 3D) *unless* the richer one genuinely adds comprehension or the doc is a showcase.

The full how-to for each lives in the reference files above (charts, mermaid, tables, 3D scenes, scrollytelling, stylized renders) — this table is just the trigger so the right treatment gets considered every time.

## Capability Routing

After choosing long-form, deck, or both, route each content shape to the smallest reference that covers it:

- **Long-form docs:** start with `template.html`; read `page-features.md` for chrome/TOC/code blocks; add component refs based on the treatment table.
- **Slide decks:** start with `slides-template.html`; read `deck-format.md`; add component refs based on the treatment table.
- **Both:** write the long-form version first as the source of truth, then condense it into slides; share the same component choices where they still help.
- **Uploads/index:** read `sharing-and-index.md` only when the user wants to upload/update S3 or refresh the landing page.

Format decides the shell; content shape decides the component. A deck can use Mermaid, D3, ag-Grid, or three.js. A long-form doc can use the same palette with scroll-specific wiring.

## Common Mistakes

- **Embedding a screenshot of the site** — just use the CSS tokens, don't scrape images.
- **Side-stripe / left-border accents** — a colored (or even hairline) `border-left`/`border-right` on cards, callouts, blockquotes, notes, alerts, or TOC sub-lists is the classic AI tell, and it's banned here. Verdicts and decisions use the editorial `.callout` / `.verdict` treatment: centered serif text with a small gradient rule above, no box. The `card-accent` variant is reserved for one highlighted metric card, not prose.
- **Adding frameworks (Tailwind CDN, Bootstrap)** — the template is hand-rolled CSS on purpose; keep it one file, zero dependencies. The **only** sanctioned CDN exceptions are mermaid (diagrams), and — in this beta — three.js (interactive 3D), D3 (interactive charts), ag-Grid (interactive tables), and highlight.js (code syntax highlighting), each only via its documented script/importmap and only when the doc actually uses that capability.
- **Tinting every container peach** — code blocks, diagrams, and charts all sitting in the `--hover` orange box reads as monotonous "so much orange." Diagrams and charts are **white floating cards** (soft shadow, neutral hairline); code blocks are a **neutral gray panel**; inline code is a neutral chip. Let the colored content (nodes, bars) carry the color, not the container.
- **Orange Mermaid diagrams** — Mermaid defaults should be neutral/slate technical figures. Do not make every connector, node border, or diagram surface orange. Reserve orange for one deliberate highlight; use green/rose only for semantic success/risk states.
- **Reaching for a 3D scene when a chart or mermaid graph is clearer** — three.js is for relationships you want to move through (constellations, clusters, flows), never for reading exact numbers. If a 2D SVG chart or a mermaid diagram lands the point faster, that's the right tool, and it keeps the file truly self-contained.
- **Putting the only copy of a fact inside a WebGL canvas** — GPUs can be blocklisted and print mode renders 3D blank. Keep the takeaway in real HTML above the canvas.
- **Uppercasing headings** — Nest brand headings are sentence case. Don't `text-transform: uppercase`.
- **Losing the oversized H1** — the dramatic serif H1 is the whole vibe. Don't shrink it to "look professional".
- **Reaching for mermaid by default** — most summaries don't need a diagram. Use it when the geometry of the answer (topology, flow, sequence) is the answer, not as decoration.
- **Authoring data tables as plain `<table>`** — in this skill, generated HTML is net-new, so tabular data should be ag-Grid by default. Readers can sort, filter, resize, scan, and keep dark-mode-safe styling. Plain `<table>` is only for tiny non-data layout fragments or hidden accessibility mirrors for charts/grids.
- **Components that ignore the token system (the dark-mode killer)** — every CDN component must follow `--bg`/`--ink`/`--accent`, not its own fixed palette. The three traps: (1) a CDN library's *own* theme CSS with baked hex (ag-Grid Quartz, a highlight.js prebuilt theme) — drive its CSS variables from tokens instead (`--ag-background-color: var(--bg)`; an inline brand-token hljs theme, never `github.css`); (2) D3/SVG drawn with presentation *attributes* `.attr('fill','#0a0a0a')` — static strings that never re-resolve, so they vanish in dark mode; use `.style('fill','var(--ink)')` so they flip live; (3) a standalone component page that redefines a fixed `:root{--bg:#fff;--ink:#0a0a0a}` — that re-locks it to light-only Nest. Verify by toggling the gear to Dark on every theme: text must stay legible and surfaces must invert. mermaid, highlight.js, ag-Grid, and the D3 catalog examples are all already token-driven — copy their pattern, don't re-hardcode.
