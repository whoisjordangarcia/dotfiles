# nest-html-beta Examples

These files are verified, copyable references. Use them as scaffolds, not as separate deliverable types: the final output is still a long-form doc, a slide deck, or both.

## Quick Map

| File | Best for | Copy from it |
|---|---|---|
| `mermaid-and-charts-gallery.html` | Mermaid syntax choices, simple static chart patterns, diagram/chart selection | Mermaid blocks, `mermaid.initialize`, vertical bar/SVG/CSS chart markup |
| `d3-chart-catalog.html` | Interactive quantitative charts | The chart-specific render function and its matching `<svg>`/data shape |
| `table-aggrid.html` | Sortable/filterable/resizable tables | ag-Grid CDN links, token-driven Quartz variables, `columnDefs`, `rowData`, grid init |
| `longform-scrollytelling.html` | Long-form visual essays | Scroll-mounted figure lifecycle, pinned scrollytelling section, long-form JSON charts |
| `deck-scenes-and-features.html` | Interactive decks | `mountSlideScene`, `data-step` controller, presenter mode, build/reveal, deck JSON charts |
| `threejs-scene-gallery.html` | Scene selection and simple long-form WebGL figures | `data-scene` markup, `mountFigure`, ambient/point-cloud/arc/request/globe/morph/ribbon builders |
| `interactive-constellation.html` | Exploratory concept graphs | `.concept-graph` markup/CSS and `mountInteractiveGraph(figure, { nodes, edges })` |
| `threejs-stylized-renders.html` | Editorial hero/section-divider visuals | Importmap with `three/addons/`, composer wiring, toon/mesh-gradient/halftone/pixelate/riso builders |

## Copy Rules

- Copy the smallest working scaffold that covers the selected treatment.
- Keep the mount/dispose lifecycle intact; only change content/data.
- Keep token names (`--bg`, `--ink`, `--accent`, `--accent-2`, `--accent-3`) so copied components inherit the template theme.
- When copying standalone examples into `../template.html` or `../slides-template.html`, prefer the template's existing token/settings system over the example's demo-only page shell.
- Do not put the only copy of a fact inside a canvas. Keep the takeaway in real HTML.
- For decks, use `deck-scenes-and-features.html` for active-slide wiring. For long-form, use `longform-scrollytelling.html` or `threejs-scene-gallery.html` for scroll-mounted wiring.

## Theme Caveat

`mermaid-and-charts-gallery.html`, `d3-chart-catalog.html`, and `table-aggrid.html` include the full multi-theme settings demo. Some three.js examples are lighter standalone galleries; when porting their scenes into a generated doc/deck, wire colors to the generated template's tokens and test light/dark mode.
