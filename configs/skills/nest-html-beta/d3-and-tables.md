# D3 Charts and ag-Grid Tables

Use when the output needs interactive quantitative charts or sortable/filterable tables.

## Interactive tables (ag-Grid) — beta

Use **ag-Grid Community** for authored tabular data by default. Recommendations tables, audit rows, issue lists, resource/cost inventories, before/after comparisons, and any row/column data should be grid-backed so readers can sort, filter, resize, and scan without the author hand-tuning a static table. It's the same engine the Nest app's `DataGrid` wraps, so it matches what the team already uses, and it's a deliberate CDN exception like mermaid / D3 / three.js.

Plain `<table>` is only allowed for:
- Tiny non-data layout fragments where sorting/filtering would be silly.
- Hidden accessibility mirrors for SVG/D3/ag-Grid data.

Treat each output as net-new HTML. When the content has meaningful row/column data, author it as ag-Grid instead of a static table.

Assume readers are online. Do not avoid ag-Grid because it loads from a CDN. Still keep the key conclusions in prose above the grid so the page scans well, prints well, and remains understandable before the grid finishes loading.

A bundled, runnable reference ships with this skill: **`examples/table-aggrid.html`** — sortable, column-filtered, resizable, and **theme + light/dark/system aware**. Open it, copy the wiring, swap the `columnDefs` / `rowData`.

**Wiring** — three CDN tags (pin the version) and one `createGrid` call. If the document has more than one table, create one grid container per table with stable IDs (`recommendations-grid`, `cost-grid`, etc.) and call `agGrid.createGrid` for each:

```html
<link href="https://cdn.jsdelivr.net/npm/ag-grid-community@31.3.2/styles/ag-grid.css" rel="stylesheet">
<link href="https://cdn.jsdelivr.net/npm/ag-grid-community@31.3.2/styles/ag-theme-quartz.css" rel="stylesheet">
<script src="https://cdn.jsdelivr.net/npm/ag-grid-community@31.3.2/dist/ag-grid-community.min.js"></script>
```
```js
agGrid.createGrid(document.getElementById('grid'), { columnDefs, rowData, defaultColDef: { sortable: true, resizable: true } });
```
The grid mounts into `<div id="grid" class="ag-theme-quartz" style="height:360px;width:100%">`. Size the height to the data; short grids can be ~280px, longer grids can be 520-760px. Avoid `domLayout: "autoHeight"` for large tables because it can create very tall pages.

**Brand theming (theme + light/dark/system aware).** ag-Grid Quartz is themed entirely through `--ag-*` CSS variables. The whole trick to making it mode-aware is to point those variables at the page tokens (`--bg`, `--ink`, `--accent`) instead of literal hex — then the grid re-skins per theme **and** flips with light/dark/system automatically, with zero JS and no second stylesheet. Drive the *base* surfaces (`--ag-background-color`, `--ag-foreground-color`) — that's what makes dark mode actually work — and **don't forget the popup/menu backgrounds**, or the column-filter menu stays white in dark mode (the classic miss):

```css
.ag-theme-quartz{
  --ag-font-family: var(--sans);
  /* base surfaces — these make dark mode work */
  --ag-background-color: var(--bg);
  --ag-foreground-color: var(--ink);
  --ag-secondary-foreground-color: var(--ink-soft);
  --ag-data-color: var(--ink);
  --ag-odd-row-background-color: color-mix(in oklch, var(--ink) 3%, var(--bg));
  /* header + borders + rows */
  --ag-header-background-color: color-mix(in oklch, var(--accent) 12%, var(--bg));
  --ag-header-foreground-color: var(--ink);
  --ag-border-color: var(--border);
  --ag-row-border-color: color-mix(in oklch, var(--ink) 10%, transparent);
  --ag-row-hover-color: var(--hover);
  --ag-selected-row-background-color: color-mix(in oklch, var(--accent) 14%, transparent);
  /* accents: sort/focus, checkboxes, range selection */
  --ag-active-color: var(--accent);
  --ag-input-focus-border-color: var(--accent);
  --ag-range-selection-border-color: var(--accent);
  /* popups: filter menu, dropdowns, control panel — keep them on-theme in dark */
  --ag-control-panel-background-color: var(--bg);
  --ag-menu-background-color: var(--bg);
  --ag-popup-background-color: var(--bg);
  --ag-input-background-color: var(--bg);
  --ag-wrapper-border-radius: 10px;
}
```

In a doc generated from `template.html` these tokens already exist, so the grid follows the reader's gear setting for free. In a standalone table page, include the token block + a settings gear (as `examples/table-aggrid.html` does). **Never** re-introduce a fixed `:root{--bg:#fff;--ink:#0a0a0a}` for the grid page — that's what locked the old example to light-only Nest.

## Interactive charts (D3) — beta

The inline SVG charts above are static by design. When the reader genuinely needs to **hover to read exact values**, follow a trend over time, or explore a distribution or network, use **D3**. Like three.js, this is a deliberate CDN exception to the "no dependencies / no interactivity" rules — use it only when interactivity earns its place; the static SVG charts stay the default for at-a-glance summaries.

A bundled, runnable reference ships with this skill: **`examples/d3-chart-catalog.html`** — **20 interactive chart types**, brand-themed and self-contained, with an **Animate** toggle (line paths draw themselves, everything else staggers in on scroll; reduced-motion aware). Open it, copy the function for the chart you want, swap the data.

**Pick the chart by the shape of the data** (all 20 live in the catalog file):

| Data shape | Chart |
|---|---|
| Trend over time | **Line** (multi-series, shared crosshair) |
| Cumulative / volume over time | **Area** |
| Compare categories across groups | **Grouped bar** |
| Part-to-whole across categories | **Stacked bar** |
| Ranked list | **Ranking bar** or **Lollipop** |
| Correlation of 2–3 variables | **Scatter / bubble** |
| Parts of a whole | **Pie** or **Donut** |
| One value vs a target | **Radial gauge** |
| Distribution of one variable | **Histogram** |
| Hierarchy by magnitude | **Treemap** or **Circle pack** |
| Hierarchy, radial | **Sunburst** |
| Flows between a few nodes | **Chord** |
| Multi-attribute comparison | **Radar** |
| Before → after, a few items | **Slope** |
| Composition shifting over time | **Streamgraph** |
| Relationships / network | **Force-directed** (draggable) |

**Wiring:**
- CDN in `<head>`: `https://cdn.jsdelivr.net/npm/d3@7`. Assume readers are online; D3 interactivity is allowed when it earns its place. Keep the core takeaway in real HTML too for accessibility, print, and first-pass scanning.
- **Brand theming (theme + light/dark/system aware):** the *categorical series* palette stays fixed-brand — orange `#e65732`, purple `#a367c8`, rose `#c45567`, amber `#e78d32` (these read on both light and dark, so the encoding is stable across modes). But every *structural* color — axes, grid, tick text, crosshair, tooltip, donut/gauge centerpiece, node fills, slice separators — must derive from the page tokens so it flips with mode and re-skins per theme. **The trick:** SVG presentation *attributes* (`.attr('fill', '#0a0a0a')`) are static strings that never re-resolve, but the SVG `fill`/`stroke` *CSS properties* accept `var()` and update live when `--ink`/`--bg` change. So set structural colors with `.style('fill','var(--ink)')` / `.style('stroke','var(--bg)')` — **not** `.attr(...)` — and they track the gear's theme/mode toggle with **no re-render**. Two leverage points the catalog uses:
  - A stylesheet rule beats a presentation attribute, so `.axis text{fill:var(--ink-soft)} .axis line{stroke:var(--grid)} .axis .domain{stroke:var(--axis)}` re-themes every cartesian chart's axes/grid at once — the `gridStyle`/`axisStyle` helpers still set inline strokes, but the CSS overrides them. Define `--grid`/`--axis` from `--accent` via `color-mix`.
  - The tooltip inverts with mode: `.tip{background:var(--ink);color:var(--bg)}` (dark chip on light, light chip on dark). The catalog also defines shared `tip` + `show/hide` helpers — reuse them so every chart matches the page.
  Series colors are the *only* literal hex left in the chart JS; if you see `.attr('fill','#0a0a0a')` or `rgba(10,10,10,…)` in lifted code, convert it to a `.style(...,'var(--…)')` token ref or it will vanish in dark mode.
- **Accessibility (required):** give the `<svg>` `role="img"` + a plain-language `aria-label`, plus a visually-hidden `<table class="sr-only">` of the data — an SVG chart is otherwise silent to a screen reader. The catalog shows the pattern.
- **Decks:** build the chart when its slide becomes `.active` (a hidden svg has zero size), the same lazy pattern as mermaid. **Long-form:** render on load, or on scroll-in via `IntersectionObserver`.
- **Reduced motion:** the Animate toggle defaults off under `prefers-reduced-motion`. Its animation **guards against re-entry** — d3 cancels a *pending* (delayed, not-yet-started) transition without firing `interrupt`, which can strand a chart at opacity 0; the guard + an `on('end interrupt')` opacity reset means a chart can never be left invisible. Reuse that guard if you lift the animate code.
