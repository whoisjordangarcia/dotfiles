# Slide Deck Format

Use when the output is a deck, presentation, decision deck, or when generating both long-form and deck variants.

## Slide deck format (when the user asks for a deck)

If the user asks for a "deck", "slides", "presentation", "decision deck", or "for a meeting", produce a **slide deck** alongside (or instead of) the long-form doc. The deck uses the **same brand theme** as the long-form — Instrument Serif H1 with orange→purple gradient, white background, brand orange accent, all five themes (Nest/Slate/Forest/Paper/Dusk), light/dark mode — so a reader who has Slate dark mode set on the long-form sees the deck in Slate dark mode too. Theme + Mode preferences persist via the same `localStorage` keys (`nest-doc-theme`, `nest-doc-mode`).

Decks can use the same component palette as long-form docs: Mermaid for flows, D3/SVG for numbers, ag-Grid for tabular evidence, three.js for spatial relationships and hero scenes, and stylized renders for editorial section breaks. `examples/deck-scenes-and-features.html` shows slide-specific wiring (`active` slides, `data-step`, presenter mode); `examples/longform-scrollytelling.html` shows scroll-specific wiring (`IntersectionObserver`, pinned scrollytelling). Pick the component by the content shape, then use the format's wiring pattern.

For three.js in a deck, the scene should usually **own the slide**: put `data-scene` on the `<section class="slide">`, place the canvas as a direct slide child, and layer the real HTML takeaway above it. Do not drop a small bordered long-form figure inside a deck slide unless the 3D view is genuinely secondary.

For Mermaid flow diagrams in a deck, use the lightweight flow treatment from `mermaid-and-svg.md` when the diagram represents movement, routing, handoff, or lifecycle direction. The slide should not look like a pasted static SVG: keep real explanatory copy beside the diagram, use a subtle CSS-only dashed edge animation after Mermaid renders, and respect `prefers-reduced-motion`. Do not add SVG pulse dots or `animateMotion` loops in decks; they are too heavy for presentation pages.

For bento-style coverage slides, hierarchy matters more than filling boxes. Use one dominant tile plus a few crisp proof tiles, strong contrast, and short labels. Avoid washed-out same-weight cards, giant translucent background letters, blurry peach haze, or copy that wraps until it clips. If the bento does not clarify the system faster than a simple list, use a simpler layout.

The deck format adds slide navigation, a slide counter, a jump-to-slide outline modal, keyboard shortcuts, and a print-to-PDF mode that reveals all slides for export.

### When a deck is right vs. long-form

| Content | Use |
|---|---|
| Background reading, deep-dive write-ups, plans with rationale | **Long-form** |
| Decision meeting, status update, exec review, stand-up walkthrough | **Deck** |
| Both — async readers AND a meeting | **Generate both** (`<slug>.html` and `<slug>-deck.html`) |
| Live presentation where someone clicks through | Deck |
| Asynchronous read where the audience scrolls top-to-bottom | Long-form |

When the same content is needed in both formats (common for plans being presented), generate **both** files from the same source material. The deck is a condensed version of the long-form: the long-form's lede becomes the title slide subtitle; each major H2 section becomes one slide; the recommendation block becomes an editorial `.callout` (centered serif text + gradient rule, no box); tables stay as ag-Grid tables when they contain meaningful row/column data; appendix slide links back to the long-form.

### Wiring it up

Read `slides-template.html` from this skill directory. Placeholders:

| Placeholder | Fill with |
|---|---|
| `{{TITLE}}` | Deck title (also used as `<title>`). Used both in `<head>` and on the title slide H1. |
| `{{EYEBROW}}` | Top-line context shown above the H1 on the title slide. Convention: `<TICKET> · <KIND> · <AUDIENCE>` — e.g. `NES-4326 · Decision deck · For engineering review`. CSS uppercases it. |
| `{{SUBTITLE}}` | One-sentence framing on the title slide (the lede). |
| `{{DATE}}` | `YYYY-MM-DD` or `Month D, YYYY`. |
| `{{AUTHOR}}` | Presenter name. |
| `{{SLIDES}}` | The `<section class="slide">` blocks for each content slide. |
| `{{FOOTER_LEFT}}` | Left footer text shown on every slide (e.g. ticket + topic). |

Each content slide is a `<section class="slide">` (no `active` class — only the title slide starts active). The template's `<script>` block already handles theme/mode persistence, slide navigation, slide counter, jump-to-slide outline, keyboard shortcuts, and print-to-PDF.

### Built-in features (don't re-implement)

| Feature | How it works |
|---|---|
| **Settings panel (gear icon top-right)** | Theme + Mode pickers, identical to long-form doc. Persisted via `nest-doc-theme` and `nest-doc-mode` localStorage keys. Dropped Layout/Contents — those don't apply to decks. |
| **Slide outline modal** | Press `Esc` or `O` to open. Lists all slides as clickable links pulled from each slide's first heading. Arrow keys navigate, Enter jumps, number keys jump directly. |
| **Number-key jump** | Press `1`–`9` to jump to that slide directly (works whether outline is open or closed). |
| **Hash deep-link** | `#3` in the URL jumps to slide 3. Updates on every slide change so the URL stays linkable. |
| **Slide counter** | Top-right `1 / N` updates automatically from `slides.length` — you don't fill `N`. |
| **Prev/Next buttons** | Bottom-right, same look as long-form doc settings panel. |
| **Print mode** | `@media print` reveals all slides with page breaks between them. `Cmd+P → Save as PDF` produces a shareable handout. The H1 gradient becomes solid black for paper readability. |

### Slide patterns (use these, don't reinvent)

```html
<!-- Standard content slide -->
<section class="slide">
  <p class="eyebrow">Section name</p>
  <h2>Slide headline that carries the point</h2>
  <p class="lead">One-sentence framing for what's on this slide.</p>
  <ul>
    <li>Point one</li>
    <li>Point two</li>
  </ul>
</section>

<!-- Stats slide (1, 2, 3, or 4 cards) -->
<section class="slide">
  <p class="eyebrow">Findings</p>
  <h2>The headline number.</h2>
  <div class="grid-3">
    <div class="card card-accent">
      <h4>Conversions</h4>
      <div class="val">94%</div>
      <p class="sub">n = 250 sessions</p>
    </div>
    <div class="card"><h4>Updated</h4><div class="val">71%</div></div>
    <div class="card"><h4>Stuck</h4><div class="val">29%</div></div>
  </div>
</section>

<!-- Two-column comparison -->
<section class="slide">
  <p class="eyebrow">Today vs. target</p>
  <h2>Two paths.</h2>
  <div class="two-col">
    <div>
      <h3>Today</h3>
      <ul><li>...</li></ul>
    </div>
    <div>
      <h3>Target</h3>
      <ul><li>...</li></ul>
    </div>
  </div>
</section>

<!-- Inline horizontal bars (rankings, distributions) -->
<section class="slide">
  <p class="eyebrow">Browser distribution</p>
  <h2>Where the traffic comes from.</h2>
  <div class="bar-row">
    <span class="bar-label">Safari iOS &lt; 17</span>
    <span class="bar-wrap"><span class="bar-fill" style="width:62%"></span></span>
    <span class="bar-val">62% (n=124)</span>
  </div>
</section>

<!-- Callout slide (the single takeaway; editorial, not a bordered card) -->
<section class="slide">
  <p class="eyebrow">Recommendation</p>
  <h2>What we should do.</h2>
  <div class="callout">
    <strong>Ship the change.</strong> The data shows X, Y, and Z. Risk is bounded by the rollback path on slide 9.
  </div>
</section>
```

### Critical gotchas

1. **One idea per slide.** A slide that needs scrolling is too dense — split it. Ten slides with one bullet each beats one slide with ten bullets.
2. **Title slide must be FIRST and have `class="slide active title-slide"`.** Only one slide can have `active` at any time; the controller toggles it on navigation.
3. **The slide counter auto-updates** from `slides.length`. Don't fill the count manually.
4. **Don't introduce ad-hoc colors.** The brand themes already define `--accent`, `--accent-2`, `--accent-3`. Card variants are `card`, `card-accent` (full accent-colored border + soft accent wash + accent-colored value — signals one highlighted metric, not prose). `.callout` is the non-boxed editorial verdict treatment. If you need more than that, you're probably trying to put too much on one slide.
5. **The eyebrow is sentence-case in source, uppercase in render.** Write `<p class="eyebrow">Today vs. target</p>` — CSS handles the uppercase + letter-spacing.
6. **Headings carry the point** — `<h2>` should state the takeaway as a sentence, not a category. "Three bugs and one structural concern." reads better than "Findings".
7. **Print mode is the PDF export path.** Don't break it with `display: none` rules without an `@media print` reset.

### Choosing between formats (or both)

Default decision tree:
- User asks for a **plan / write-up / investigation / spec** → long-form.
- User asks for a **deck / slides / presentation / decision** → deck.
- User asks for **both** → generate both, name them `<slug>.html` and `<slug>-deck.html`, share both URLs.
- User is ambiguous → ask: *"Long-form HTML doc, slide deck, or both?"* Default to long-form if no answer.

When generating both: write the long-form first (it's the source of truth for the content), then condense it into slides. The deck's appendix slide should link back to the long-form for readers who want depth.
