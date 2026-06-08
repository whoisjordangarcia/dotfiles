# Long-Form Page Features

Use when composing long-form docs from `template.html`, adding built-in page chrome, or deciding whether to include a sidebar TOC.

## Global page features (already in `template.html`)

Every page produced by this skill ships with these — the template's CSS and JS handle them. Authors only write semantic HTML.

A floating gear button in the top-right opens a settings panel with four controls, each persisted to `localStorage` and applied pre-paint via an inline `<head>` script (no flash on reload):

| Setting | What it does | Storage key |
|---|---|---|
| **Theme** | Color palette swatches: Nest, Slate, Forest, Paper, Dusk. Each theme defines its own `--accent` and a `--bg-light`/`--bg-dark` pair, so the H1 gradient and surface tints re-skin together. | `nest-doc-theme` |
| **Mode** | Light / Dark / System. Independent of Theme. System follows `prefers-color-scheme`. Each theme has its own dark variant — Forest dark is deep green, Slate dark is navy, Paper dark is warm cocoa, etc. | `nest-doc-mode` |
| **Width** | Narrow (720) / Wide (960) / Full (1200). Drives `--content-width`; `main` transitions between them. | `nest-doc-width` |
| **Contents** | Show/hide toggle for the sidebar TOC. Only appears in the panel when a `.toc` exists on the page. Hidden TOC also collapses the body's left padding so the article reflows. | `nest-doc-toc` |

**Other global behaviors:**

| Feature | What you must do |
|---|---|
| **Heading anchors (`#` on hover)** | Always give every `<h2>` and `<h3>` a slugged `id` (e.g. `<h2 id="findings">Findings</h2>`). The template injects a `#` link on hover that copies the deep URL to clipboard. No `id` → no anchor. |
| **Smooth scroll** | Built in via `scroll-behavior: smooth` on `html`, with `scroll-margin-top` on every heading. TOC clicks ease to the section. Respects `prefers-reduced-motion`. |
| **Scroll-spy sidebar + sliding pill** | Just include a `.toc` aside (see below). The template auto-numbers top-level entries (01, 02, … via a CSS counter) and injects a single **sliding pill** that glides (`transform`+`height`) to the section you're currently in. It always tracks the current section (the last heading scrolled past the top band) and highlights instantly on click — no `IntersectionObserver` narrow-band gaps. Nothing to author. |
| **Collapsible sidebar** | The sidebar's `<details>` chevron collapses it sideways into a small floating chevron pill at the left edge — not vertically. Coordinated `width` / `padding` / `border-radius` transition handles the morph. |
| **Reading time** | Long-form only: the template counts rendered words in `.content` (÷220 wpm) and appends e.g. ` · 4 min read` to the byline automatically. Decks/index have no `.content`, so it doesn't appear there. Nothing to author. |
| **Code blocks: copy + highlight** | Every `<pre>` gets a hover-reveal **Copy** button automatically. If the doc contains code blocks, the template normalizes bare `<pre>` nodes into `<pre><code>`, infers a language when possible, lazy-loads highlight.js, and applies the **brand-token** syntax theme (keywords `--accent-3`, strings/comments mixed with `--ink`) — so highlighting tracks theme + light/dark. Always write new blocks as ```` <pre><code class="language-tsx">…</code></pre> ````; no wiring needed. |
| **Dates → long US format** | Wrap any date in `<time class="doc-date">…</time>` (the template's byline/footer already do). An ISO `YYYY-MM-DD` is auto-rendered as `June 4, 2026` and gets a machine-readable `datetime` attribute; a date already written as prose is left as-is. Fill `{{DATE}}` with the ISO date and let the template format it. |
| **Reading-progress bar** | A thin bar fixed at the very top of the viewport fills left-to-right (in the brand H1 gradient) as the reader scrolls toward the end, so they always know how far through they are. Automatic; nothing to author. |

Color tints (`--ink-soft`, `--border`, `--hover`, `--peach`, `--tan`) are derived from `--ink` and `--accent` via `color-mix(in oklch, ...)`, so adding a sixth theme later only requires defining the four bg/ink values plus an accent — supporting surfaces compute automatically.

## Verdicts and decision callouts

Use `.callout`, `.verdict`, or `.decision` for the single point a reader should remember. These are editorial pull-quotes: centered serif text, a short gradient rule above, and no surrounding box. Do not wrap prose decisions in bordered cards, peach panels, or side-stripe alerts.

## Rich long-form structure

When the user asks for a flagship long-form doc, a visual showcase, or "all variations," do not mirror the deck as a plain sequence of sections. Use the long-form affordances:

- Start with a bento-style overview that explains the component coverage at a glance instead of a row of same-weight chips.
- Let each major content shape get its own article section: Mermaid flow, ag-Grid table, D3 chart/gallery, code block, three.js scene/gallery, and scrollytelling when the story unfolds step-by-step.
- Use gallery sections only when comparison is the point. A D3 or three.js gallery is appropriate for a component audit or showcase; a normal team write-up should choose the one treatment that best explains the content.
- Keep the core takeaway in real HTML prose near every canvas/SVG. WebGL, D3, and Mermaid can add comprehension, but they should never be the only place the reader can understand the claim.

## Long content: offer a collapsible sidebar TOC

If the summary has **4 or more `<h2>` sections** (or any meaningful `<h3>` nesting), pause before writing the file and ask:

> *"This is getting long — want me to add a collapsible sidebar table of contents on the left so the team can jump around?"*

If yes, drop this `<aside>` **inside `<main>`, before `<header>`**. All styling and scroll-spy behavior is already in the template.

```html
<aside class="toc" aria-label="Table of contents">
  <details open>
    <summary>
      <span class="toc-eyebrow">Contents</span>
      <span class="toc-chevron" aria-hidden="true">‹</span>
    </summary>
    <nav>
      <ul>
        <li><a href="#what-were-doing">What we're doing</a></li>
        <li>
          <a href="#tables">Tables we're touching</a>
          <ul>
            <li><a href="#how-tables-relate">How the tables relate</a></li>
            <li><a href="#test-coverage">Test coverage</a></li>
          </ul>
        </li>
        <li><a href="#scoping">Scoping</a></li>
        <!-- one <li> per H2; nested <ul> for H3s under it -->
      </ul>
    </nav>
  </details>
</aside>
```

Anchors in the TOC must match the `id` values on the headings exactly. Don't ship this on short summaries (1–3 sections) — they read better without it.

## Code blocks (neutral surface + syntax highlighting)

Code in a summary is common (a buggy snippet, a config, a query). Two rules keep it clean.

**Surface: neutral, not orange.** A code block is a **neutral light-gray panel**, never the peach `--hover` tint — stacking tinted boxes (code + diagrams + charts) makes a page read as wall-to-wall orange. Inline code chips go neutral too, not accent-tinted:

```css
/* theme-aware: tracks data-mode + the 5 themes via the template's --bg/--ink */
pre, code.block {
  background: color-mix(in oklch, var(--ink) 5%, var(--bg));
  border: 1px solid color-mix(in oklch, var(--ink) 9%, transparent);
  border-radius: 10px;
  padding: 14px 16px;
  overflow-x: auto;
  font-family: var(--mono);
  font-size: 13.5px;
  line-height: 1.55;
  color: var(--ink);
}
:not(pre) > code, code.inline {
  font-family: var(--mono);
  background: color-mix(in oklch, var(--ink) 7%, transparent);   /* not var(--hover) — keep inline code off the orange */
  color: var(--ink);
  padding: 2px 6px;
  border-radius: 4px;
}
```

**Syntax highlighting** when the block is real code — add highlight.js, a CDN exception that's *conditional* on the doc actually having code:

Load only the highlight.js **engine** (no prebuilt theme CSS), then supply a **brand-token theme** so the token colors track `--ink`/`--accent` — i.e. they re-skin per theme *and* flip with light/dark/system automatically:

```html
<!-- in <head> — engine only, no github.css (a fixed theme wouldn't be theme/mode aware) -->
<script src="https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@11.9.0/highlight.min.js"></script>
<style>
  pre code.hljs, code.hljs, .hljs { background: transparent; padding: 0; color: var(--ink); }
  .hljs-comment, .hljs-quote { color: color-mix(in oklch, var(--ink) 45%, transparent); font-style: italic; }
  .hljs-keyword, .hljs-selector-tag, .hljs-literal, .hljs-section, .hljs-name, .hljs-tag { color: var(--accent-3); }
  .hljs-string, .hljs-attr, .hljs-regexp { color: color-mix(in oklch, var(--accent-2) 62%, var(--ink)); }
  .hljs-number, .hljs-built_in, .hljs-type, .hljs-symbol, .hljs-bullet { color: var(--accent-2); }
  .hljs-title, .hljs-title.function_, .hljs-title.class_, .hljs-property, .hljs-meta { color: color-mix(in oklch, var(--accent-3) 60%, var(--ink)); }
  .hljs-variable, .hljs-attribute, .hljs-template-variable, .hljs-params { color: var(--ink); }
  .hljs-emphasis { font-style: italic; } .hljs-strong { font-weight: 700; }
</style>
```
```js
// put code in <pre><code>…</code></pre>; highlight after load
document.querySelectorAll('pre code, code.block').forEach(el => { try { hljs.highlightElement(el); } catch (e) {} });
```

- New code blocks must live in `<pre><code class="language-…">…</code></pre>` — choose the closest language (`language-tsx`, `language-typescript`, `language-bash`, `language-hcl`, `language-json`, etc.). The template defensively repairs bare `<pre>` blocks by wrapping their contents in `<code>` and inferring a language, but don't rely on that for newly-authored docs.
- Do not leave code examples as inline `<code>` inside paragraphs or table cells when they are multi-line snippets. Promote them to `<pre><code class="language-…">…</code></pre>` so they get the neutral block surface, copy button, and syntax highlighting.
- **Why no github.css:** a prebuilt theme hard-codes hex token colors, so it's wrong in dark mode and ignores the 5 brand themes. Deriving colors from `--accent`/`--ink` via `color-mix` makes the syntax theme follow whatever theme + mode the reader has set (keywords/tags stay purple `--accent-3`, which reads on light *and* dark; strings/comments mix with `--ink` so they lighten in dark mode).
- Assume readers are online. Skip highlight.js only when the doc has no code, not because it loads from a CDN.

## Tables

Author tabular data as ag-Grid, not plain `<table>`. See `d3-and-tables.md` and `examples/table-aggrid.html` for the token-driven Quartz setup. Generated docs are net-new HTML: do not preserve static table markup when the content is meaningful row/column data. The CSS in `template.html` for regular tables is only a defensive baseline for tiny non-data layout fragments and hidden accessibility mirrors.
