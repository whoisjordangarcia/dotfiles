# Three.js Scenes

Use when the doc or deck earns an interactive 3D scene, stylized hero, spatial graph, request trace, globe, morph, or scrollytelling treatment.

## Interactive 3D visualizations (three.js) — beta

Some content is *spatial* or *relational* in a way a flat chart can't carry: a concept map where everything connects to everything, an embedding cluster, a topology you want to rotate and inspect. For those, the beta skill can drop a live **three.js / WebGL** scene onto a slide (or into a long-form doc). This is the one place the "zero external dependencies" rule bends — three.js is too large to inline, so it loads from a CDN via an `importmap`.

> **Online assumption.** Nest docs are read online, so CDN-loaded three.js is allowed when the content earns it. Do not avoid 3D scenes because they load from a CDN. Still keep the core message in real HTML near the scene for accessibility, print/PDF export, and rare WebGL/GPU failures.

### When a 3D scene earns its place

| Content | Use |
|---|---|
| A web of concepts where the *connections* are the point (glossary, architecture map, "everything touches the Agent") | **Force-directed constellation** |
| Clusters / embeddings / any 3-axis data where the *shape* matters | **3D point cloud** |
| Integrations, data flows, dependency topology with directional movement | **Arc network** |
| Title-slide atmosphere only — no data | **Ambient particle backdrop** |
| A quantity the reader must read off precisely (94%, 4.0 vs 4.3) | **NOT 3D** — use the inline SVG charts. 3D is for relationships and space, never for reading exact values. |

The discipline from the chart section still holds: **charts are for quantities, diagrams for relationships, 3D for relationships you want to move through.** If a 2D SVG or a mermaid graph says it more clearly, use that — a spinning graph that's harder to read than a list is decoration, and decoration is a regression here.

### Light backgrounds: `NormalBlending`, never additive

Nearly every three.js demo online targets a **dark** page and uses `AdditiveBlending` so overlapping light *accumulates* into glow. On the brand's **white** background that washes straight to invisible — the single most common reason a ported scene "renders nothing." The rule for every scene here:

- Use **`NormalBlending`** (the default) with `transparent: true, depthWrite: false`. Never `AdditiveBlending`.
- **White is the empty/base; a brand hue is the mark** — density should read as *darker ink*, not brighter glow. Keep colours dark enough to show on white: ink `#0a0a0a`, orange, purple, and rose all read; **amber `#e78d32` is too pale on white** — use it only as a hover/accent tint, never to carry meaning.
- Porting a dark demo: swap `AdditiveBlending → NormalBlending`, keep `renderer.setClearColor(0x000000, 0)` with `alpha:true` so the white page shows through, recolour to the brand. If it then looks flat, add a soft **halo** — a `Sprite` with a radial-gradient `CanvasTexture`, brand-coloured, `opacity ~0.2`, `NormalBlending` — not glow.

### Wiring it in

**1. Add the importmap in `<head>`** (pin the version; `unpkg` per the chosen loader). Importmap must be a classic `<script>`, before any module script:

```html
<script type="importmap">
{ "imports": { "three": "https://unpkg.com/three@0.160.0/build/three.module.js" } }
</script>
```

**2. Give the slide a canvas + a content layer.** The canvas fills the slide; real HTML (heading, detail panel) sits above it so the slide stays readable and accessible even if WebGL fails:

```html
<section class="slide">
  <canvas class="gl" aria-hidden="true"></canvas>
  <div class="gl-content two-col">
    <div></div><!-- left half left open for the scene to show through -->
    <div>
      <p class="eyebrow">Concept map</p>
      <h2>Everything connects to the Agent.</h2>
      <p class="lead" id="gl-detail">Hover a node to inspect it.</p>
    </div>
  </div>
</section>
```

```css
.slide canvas.gl { position: absolute; inset: 0; width: 100%; height: 100%; display: block; z-index: 0; }
.slide .gl-content { position: relative; z-index: 1; pointer-events: none; } /* text above the scene */
.slide .gl-content a, .slide .gl-content button { pointer-events: auto; }
```

**3. Mount the scene with the shared scaffold.** This is the load-bearing helper — it sizes the canvas for retina, and (critically) **only runs the render loop while the slide is `.active`**, disposing the GL context when you navigate away so a multi-slide deck never exceeds the browser's ~16-context cap. It also renders a single static frame under `prefers-reduced-motion`:

```html
<script type="module">
import * as THREE from 'three';

// Brand palette as THREE colors — matches the deck's CSS tokens exactly.
const BRAND = {
  ink:    new THREE.Color('#0a0a0a'),
  orange: new THREE.Color('#e65732'),
  amber:  new THREE.Color('#e78d32'),
  purple: new THREE.Color('#a367c8'),
  rose:   new THREE.Color('#c45567'),
};

// Round soft-edged sprite so nodes are dots, not squares. Built once, reused.
function discTexture() {
  const s = 64, c = document.createElement('canvas'); c.width = c.height = s;
  const g = c.getContext('2d'); const grad = g.createRadialGradient(s/2, s/2, 0, s/2, s/2, s/2);
  grad.addColorStop(0, 'rgba(255,255,255,1)'); grad.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = grad; g.beginPath(); g.arc(s/2, s/2, s/2, 0, Math.PI*2); g.fill();
  const t = new THREE.CanvasTexture(c); t.needsUpdate = true; return t;
}

// Mount a WebGL scene on one slide. `build(scene, camera, ctx)` returns an
// optional `update(timeSeconds)` called each frame. Lifecycle is tied to the
// slide's `.active` class so the loop pauses (and the context frees) off-screen.
function mountSlideScene(slideEl, build) {
  const canvas = slideEl.querySelector('canvas.gl');
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  let renderer, scene, camera, update = () => {}, raf = 0, mounted = false;

  function size() {
    const r = canvas.getBoundingClientRect();
    renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 2));
    renderer.setSize(r.width, r.height, false);
    camera.aspect = (r.width || 1) / (r.height || 1);
    camera.updateProjectionMatrix();
  }
  function mount() {
    if (mounted) return; mounted = true;
    renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
    scene = new THREE.Scene();
    camera = new THREE.PerspectiveCamera(50, 1, 0.1, 200);
    camera.position.set(0, 0, 18);
    update = build(scene, camera, { THREE, BRAND, disc: discTexture, canvas }) || (() => {});
    size(); ro.observe(canvas);
    const t0 = performance.now();
    const loop = (t) => { update((t - t0) / 1000); renderer.render(scene, camera); raf = requestAnimationFrame(loop); };
    if (reduce) { update(0); renderer.render(scene, camera); }   // one static frame
    else raf = requestAnimationFrame(loop);
  }
  function unmount() {
    if (!mounted) return; mounted = false;
    cancelAnimationFrame(raf); ro.unobserve(canvas);
    renderer.dispose();                                          // free the GL context
  }
  const ro = new ResizeObserver(() => { if (mounted) size(); });
  new MutationObserver(() => slideEl.classList.contains('active') ? mount() : unmount())
    .observe(slideEl, { attributes: true, attributeFilter: ['class'] });
  if (slideEl.classList.contains('active')) mount();             // title slide starts active
}
</script>
```

Every example below is a `build` you pass to `mountSlideScene(slideEl, build)`.

### Render example 1 — concept constellation (force-directed)

This is the one from the reference image: dark nodes wired together, hubs larger, the graph slowly turning. A tiny live force simulation (repulsion + springs + centering) lays it out — fine up to ~80 nodes (O(n²)). Hover raycasts a node and writes its label into the `#gl-detail` panel.

```js
function constellation(scene, camera, { THREE, BRAND, disc, canvas }) {
  const labels = ['Agent','Model','Harness','Tool','Context window','Turn','Session','Skill',
    'Subagent','Sandbox','System prompt','Memory','Handoff','AGENTS.md','AFK','Tool result'];
  const N = labels.length;
  const nodes = labels.map((name, i) => ({
    name, deg: 0,
    p: new THREE.Vector3((Math.random()-.5)*10, (Math.random()-.5)*10, (Math.random()-.5)*10),
    v: new THREE.Vector3(),
  }));
  const edges = [];
  for (let i = 1; i < N; i++) {                       // hub-and-spoke: each node links toward an earlier one
    const j = Math.floor(Math.random() * i * 0.5);
    edges.push([i, j]); nodes[i].deg++; nodes[j].deg++;
  }

  const group = new THREE.Group(); scene.add(group);
  // edges
  const lineGeo = new THREE.BufferGeometry();
  const linePos = new Float32Array(edges.length * 6);
  lineGeo.setAttribute('position', new THREE.BufferAttribute(linePos, 3));
  group.add(new THREE.LineSegments(lineGeo,
    new THREE.LineBasicMaterial({ color: BRAND.ink, transparent: true, opacity: 0.18 })));
  // nodes (sized by degree, hubs tinted brand orange)
  const ptGeo = new THREE.BufferGeometry();
  const ptPos = new Float32Array(N * 3), ptSize = new Float32Array(N), ptCol = new Float32Array(N * 3);
  nodes.forEach((n, i) => {
    ptSize[i] = 0.5 + n.deg * 0.25;
    const c = n.deg > 4 ? BRAND.orange : n.deg > 2 ? BRAND.purple : BRAND.ink;
    ptCol.set([c.r, c.g, c.b], i * 3);
  });
  ptGeo.setAttribute('position', new THREE.BufferAttribute(ptPos, 3));
  ptGeo.setAttribute('size', new THREE.BufferAttribute(ptSize, 1));
  ptGeo.setAttribute('color', new THREE.BufferAttribute(ptCol, 3));
  const ptMat = new THREE.ShaderMaterial({
    uniforms: { map: { value: disc() } },
    vertexColors: true, transparent: true, depthWrite: false,
    vertexShader: `attribute float size; varying vec3 vC;
      void main(){ vC = color; vec4 mv = modelViewMatrix*vec4(position,1.0);
      gl_PointSize = size*300.0/-mv.z; gl_Position = projectionMatrix*mv; }`,
    fragmentShader: `uniform sampler2D map; varying vec3 vC;
      void main(){ vec4 t = texture2D(map, gl_PointCoord); if(t.a<0.1) discard;
      gl_FragColor = vec4(vC, t.a); }`,
  });
  group.add(new THREE.Points(ptGeo, ptMat));

  // hover → detail panel
  const ray = new THREE.Raycaster(); ray.params.Points.threshold = 0.6;
  const mouse = new THREE.Vector2(-2, -2);
  const detail = document.getElementById('gl-detail');
  canvas.style.pointerEvents = 'auto';
  canvas.addEventListener('pointermove', (e) => {
    const r = canvas.getBoundingClientRect();
    mouse.set(((e.clientX-r.left)/r.width)*2-1, -((e.clientY-r.top)/r.height)*2+1);
  });

  return (t) => {
    // force integration
    for (let i = 0; i < N; i++) {
      const a = nodes[i]; const f = new THREE.Vector3();
      for (let j = 0; j < N; j++) if (i !== j) {                  // repulsion
        const d = a.p.clone().sub(nodes[j].p); const l = d.length() + 0.01;
        f.add(d.multiplyScalar(2.2 / (l * l)));
      }
      f.add(a.p.clone().multiplyScalar(-0.02));                   // gravity to center
      a.v.add(f.multiplyScalar(0.016)).multiplyScalar(0.86);      // damping
    }
    edges.forEach(([i, j]) => {                                   // springs
      const d = nodes[j].p.clone().sub(nodes[i].p); const l = d.length();
      const s = d.multiplyScalar((l - 4) * 0.02);
      nodes[i].v.add(s); nodes[j].v.sub(s);
    });
    nodes.forEach((n, i) => {
      n.p.add(n.v.clone().multiplyScalar(0.5));
      ptPos.set([n.p.x, n.p.y, n.p.z], i * 3);
    });
    edges.forEach(([i, j], k) => {
      linePos.set([nodes[i].p.x, nodes[i].p.y, nodes[i].p.z], k * 6);
      linePos.set([nodes[j].p.x, nodes[j].p.y, nodes[j].p.z], k * 6 + 3);
    });
    ptGeo.attributes.position.needsUpdate = true;
    lineGeo.attributes.position.needsUpdate = true;
    group.rotation.y = t * 0.08;                                  // slow auto-turn

    ray.setFromCamera(mouse, camera);
    const hit = ray.intersectObject(group.children[1])[0];
    if (detail) detail.textContent = hit ? nodes[hit.index].name : 'Hover a node to inspect it.';
  };
}
// mountSlideScene(document.currentScript.closest('.slide'), constellation);
```

### Render example 2 — 3D point cloud (clusters / embeddings)

For "here's the shape of our data" — survey responses projected to 3D, embedding clusters, anything where grouping is the message. Points colored by cluster from the brand palette, the whole cloud drifting:

```js
function pointCloud(scene, camera, { THREE, BRAND, disc }) {
  const COUNT = 1200, clusters = [BRAND.orange, BRAND.purple, BRAND.rose, BRAND.amber];
  const pos = new Float32Array(COUNT*3), col = new Float32Array(COUNT*3);
  for (let i = 0; i < COUNT; i++) {
    const k = i % clusters.length;
    const cx = Math.cos(k/clusters.length*Math.PI*2)*5, cz = Math.sin(k/clusters.length*Math.PI*2)*5;
    pos.set([cx + (Math.random()-.5)*4, (Math.random()-.5)*6, cz + (Math.random()-.5)*4], i*3);
    col.set([clusters[k].r, clusters[k].g, clusters[k].b], i*3);
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  g.setAttribute('color', new THREE.BufferAttribute(col, 3));
  const pts = new THREE.Points(g, new THREE.PointsMaterial({
    size: 0.35, map: disc(), vertexColors: true, transparent: true, depthWrite: false,
  }));
  scene.add(pts);
  return (t) => { pts.rotation.y = t * 0.12; pts.rotation.x = Math.sin(t * 0.2) * 0.1; };
}
```

### Render example 3 — arc network (topology / flows with direction)

Nodes placed on a ring, quadratic-bezier arcs bowing between them, with a bright pulse traveling each arc to show *direction of flow* (request path, integration sync, dependency order):

```js
function arcNetwork(scene, camera, { THREE, BRAND }) {
  const N = 9, R = 7, hubs = [];
  for (let i = 0; i < N; i++) hubs.push(new THREE.Vector3(Math.cos(i/N*Math.PI*2)*R, Math.sin(i/N*Math.PI*2)*R, 0));
  scene.add(new THREE.Points(
    new THREE.BufferGeometry().setFromPoints(hubs),
    new THREE.PointsMaterial({ color: BRAND.ink, size: 0.5 })));
  const arcs = [];
  for (let i = 0; i < N; i++) {                                   // each node → two others
    [1, 3].forEach((step) => {
      const a = hubs[i], b = hubs[(i + step) % N];
      const mid = a.clone().add(b).multiplyScalar(0.5).multiplyScalar(0.55); // bow toward center
      const curve = new THREE.QuadraticBezierCurve3(a, mid, b);
      const line = new THREE.Line(
        new THREE.BufferGeometry().setFromPoints(curve.getPoints(50)),
        new THREE.LineBasicMaterial({ color: BRAND.orange, transparent: true, opacity: 0.25 }));
      scene.add(line);
      const pulse = new THREE.Mesh(new THREE.SphereGeometry(0.16, 12, 12),
        new THREE.MeshBasicMaterial({ color: BRAND.amber }));
      scene.add(pulse); arcs.push({ curve, pulse, off: Math.random() });
    });
  }
  return (t) => arcs.forEach((a) => a.pulse.position.copy(a.curve.getPoint((t * 0.25 + a.off) % 1)));
}
```

### Render example 4 — ambient particle backdrop (title slide only)

No data — just atmosphere behind the title. Thousands of faint points along the orange→purple gradient, drifting. Keep it *subtle*; it must never compete with the H1:

```js
function ambient(scene, camera, { THREE, BRAND }) {
  const COUNT = 2500;
  const pos = new Float32Array(COUNT*3), col = new Float32Array(COUNT*3);
  for (let i = 0; i < COUNT; i++) {
    pos.set([(Math.random()-.5)*40, (Math.random()-.5)*24, (Math.random()-.5)*20], i*3);
    const c = BRAND.orange.clone().lerp(BRAND.purple, Math.random());
    col.set([c.r, c.g, c.b], i*3);
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  g.setAttribute('color', new THREE.BufferAttribute(col, 3));
  const pts = new THREE.Points(g, new THREE.PointsMaterial({
    size: 0.08, vertexColors: true, transparent: true, opacity: 0.5, depthWrite: false }));
  scene.add(pts); camera.position.z = 22;
  return (t) => { pts.rotation.y = t * 0.03; pts.rotation.z = t * 0.01; };
}
```

### Runnable examples & scene catalog

The four scenes above are inlined in full. For everything else — five more scene types, the interactive-step controller, and the deck/long-form features — three verified, self-contained reference files ship with this skill. Open them, find the relevant function, copy it:

- **`examples/deck-scenes-and-features.html`** — a slide deck wiring up every scene plus deck feature: the `mountSlideScene` scaffold, six scenes, the `data-step` controller, build/reveal bullets, presenter mode, live-from-JSON charts, lazy mermaid, and the confetti finish.
- **`examples/longform-scrollytelling.html`** — the long-form counterpart: figures mounted on scroll via `IntersectionObserver` (instead of the deck's `.active` class), a scroll-driven scrollytelling section, inline mermaid, and JSON-built charts.
- **`examples/threejs-scene-gallery.html`** — seven scenes (ambient backdrop, point cloud, arc network, request trace, globe, morph, timeline ribbon) rendered together as scroll-mounted figures — the cleanest single reference for "what does each scene look like." (The concept constellation lives inline above and in `examples/interactive-constellation.html`; flythrough is in `examples/deck-scenes-and-features.html`.) It proves the mount/dispose discipline keeps WebGL contexts from coexisting, so the page never approaches the browser's ~16-context cap.

**Scene catalog** — pick by the shape of the content (the discipline from "When a 3D scene earns its place" still rules):

| Scene | Use it for | Where |
|---|---|---|
| Concept constellation | a web of concepts where the connections are the point | inline ex. 1 |
| **Interactive constellation** | a concept graph the reader *explores* — hover to preview, click to pin + zoom to centre, dynamic context panel | `examples/interactive-constellation.html`, `mountInteractiveGraph()` |
| 3D point cloud / scatter | clusters, embeddings, 3-axis data | inline ex. 2 |
| Arc network | topology / flows with direction (pulses along arcs) | inline ex. 3 |
| Ambient particle backdrop | title-slide atmosphere, no data | inline ex. 4 |
| **Flythrough** | a guided camera tour that frames one node per step (the "tour a graph stop-by-stop" feel) | `examples/deck-scenes-and-features.html`, `flythrough()` |
| **Request trace / pipeline** | how a request flows hop-by-hop, with per-hop latency labels | `examples/deck-scenes-and-features.html`, `requestTrace()` |
| **Globe with arcs** | sites / vendors on a rotating globe, integration arcs with pulses | `examples/deck-scenes-and-features.html`, `globe()` |
| **Morphing point cloud** | before → after a migration; raw → clustered, advanced on a step | `examples/deck-scenes-and-features.html`, `morph()` |
| **Timeline ribbon** | releases / milestones as cards you fly down a z-axis | `examples/deck-scenes-and-features.html`, `ribbon()` |

**The `data-step` convention** powers every stepped scene (flythrough, request-trace, morph, ribbon) and the build/reveal bullets. The controller sets an integer `data-step` on the active slide; `→` advances it (clamped to the slide's `data-steps`) before moving on; each scene reads `+slide.dataset.step` every frame and *lerps toward* that state — never snaps. In long-form, a timer or `IntersectionObserver` drives the same attribute. This decouples scenes from the controller, so copy the controller from `examples/deck-scenes-and-features.html` as-is.

**Deck & long-form features** (all in the example files; all carry a `prefers-reduced-motion` fallback where they animate):

| Feature | What it does | Where |
|---|---|---|
| Build / reveal bullets | staggers list items in, one per `→` | `examples/deck-scenes-and-features.html` |
| Presenter mode (`?present` / `P` key) | speaker notes + next-slide preview at the bottom | `examples/deck-scenes-and-features.html` |
| Live-from-JSON charts | builds brand SVG bars / donut from a `<script type="application/json">` block — edit numbers, not SVG paths | `examples/deck-scenes-and-features.html`, `examples/longform-scrollytelling.html` |
| Confetti | a tasteful brand-colored finish on the recommendation slide | `examples/deck-scenes-and-features.html` |
| Scroll-mounted figures | `IntersectionObserver` runs a scene only while on-screen, disposes when it leaves | `examples/longform-scrollytelling.html` |
| Scrollytelling | a pinned scene that advances state as the reader scrolls past prose (long-form only) | `examples/longform-scrollytelling.html` |

When you use any of these, copy the function or block from the example file verbatim and adapt its data; don't rewrite the scaffold or the controller — they're the load-bearing, already-debugged parts.

### Making a graph navigable (hover, click-to-pin, centre + zoom)

A constellation or point cloud becomes a tool, not decoration, with two interaction tiers: **hover = preview**, **click = pin**. The full, copy-paste implementation is **`examples/interactive-constellation.html`** — copy its `.concept-graph` markup + CSS and the `mountInteractiveGraph(figure, { nodes, edges })` function, then feed it your data; that's the only part you change. Everything below is what that function already gets right and you shouldn't have to rediscover:

- **Pick by screen-space projection, not raycasting.** `raycaster.intersectObject(instancedMesh)` silently misses tiny instanced spheres (the hit is fragile and the bounding sphere must be recomputed every frame — a real bug that wastes an afternoon). Project each node to pixels and take the nearest within a radius. (Raycasting `THREE.Points` with `ray.params.Points.threshold` is fine — instanced *meshes* are not.)
  ```js
  const r = canvas.getBoundingClientRect(); let id = -1, best = Infinity;
  for (let i = 0; i < N; i++) {
    v.copy(P[i]).applyMatrix4(group.matrixWorld).project(camera);
    const px = (v.x*0.5+0.5)*r.width, py = (1-(v.y*0.5+0.5))*r.height;
    const d = Math.hypot(px - mouse.x, py - mouse.y); if (d < best) { best = d; id = i; }
  }
  if (best >= 24) id = -1;                              // ~24px hit radius
  ```
- **Click → focus.** Dim every node except the target and its neighbours (precompute an adjacency set), brighten the target's edges, fade the rest. The dimming is what makes a 26-node graph legible.
- **Centre + zoom on click — translate the group, don't re-aim the camera.** Move the node *group* so the target lands at screen-centre, and dolly `camera.position.z` in. Click empty space (`selected = -1`) eases both back out.
  ```js
  const targetZ = selected >= 0 ? 9.6 : 24;             // zoom in on pin, full graph in view on release
  camera.position.z += (targetZ - camera.position.z) * 0.1;
  if (selected >= 0) { rot.copy(P[selected]).applyEuler(group.rotation);
    group.position.lerp(new THREE.Vector3(-rot.x + offX, -rot.y, 0), 0.14); } // offX nudges toward the open side, beside the panel
  else group.position.lerp(ZERO, 0.14);
  ```
- **Dynamic context panel.** A pinned node opens a card with its connections. Project the node; if it sits in the left half open the panel on the **right** (and vice-versa) so the card never covers what you clicked. Guard the stage's click handler with `if (e.target.closest('.panel')) return;` or clicks *inside* the panel deselect.
- **Settle, recentre, then build.** Run the force layout to rest *before* creating `Line2` edges / DOM labels (so they place once, not rebuilt per frame), then recentre on the centroid — `const c = mean(P); P.forEach(p => p.sub(c));` — so the graph sits dead-centre instead of drifting to a corner (gravity only *approximates* centring). A graph that clips the frame wants stronger centring + a shorter edge rest-length, not just a wider camera.
- **Labels are projected DOM**, entity names always-on with a white `text-shadow` halo so they read over edges; reproject every frame because the group rotates/parallaxes.
- **Parallax moves targets.** A pointer-parallax tilt feels alive but must be tiny (±0.13 rad, not ±0.5) or nodes drift under the cursor and clicks miss. Lock parallax while a node is pinned.

### Stylized render & shader gradients

Beyond the literal data scenes, these give a clean primitive an editorial, print-illustration register — all legible on white. **Reach for one when a doc needs a hero or section-divider moment with no data to plot** — a decision deck's title, an exec brief's opener, a launch recap, a flagship investigation's intro. The mesh-gradient backdrop is the safest (calm, no geometry); toon/halftone/riso turn a simple shape (a sphere, the Nest mark, a torus knot) into an editorial illustration. This is the treatment to default to for a "wow" opener instead of a plain `<h1>` on white. A runnable reference of all five (with the addons importmap + composer wiring already set up) ships at **`examples/threejs-stylized-renders.html`**:

| Look | How | Cost |
|---|---|---|
| **Cel / toon + ink outline** | `MeshToonMaterial` (gradientMap = a tiny `DataTexture`, `RedFormat`, `NearestFilter` for hard bands) + an inverted-hull outline: same geometry, `MeshBasicMaterial({ color: ink, side: BackSide })`, scaled ~1.045. **No composer** — cheapest stylized look. | low |
| **Halftone / newsprint** | official `HalftonePass`, greyscale dots on a white scene background. | composer |
| **Riso dither** | a ~6-line ordered-Bayer `ShaderPass` mapping luminance → white + brand ink (no texture). | composer |
| **Pixelate + edges** | `RenderPixelatedPass` — its built-in normal/depth outline keeps it crisp, not mushy. | composer |
| **Mesh gradient** | a fullscreen plane + an fbm/value-noise fragment shader, brand stops over a near-white base — a calm title backdrop or section divider. | shader |

Two non-obvious gotchas these depend on:

- **Addons load via the *same* pinned importmap** — add `"three/addons/": "https://unpkg.com/three@0.160.0/examples/jsm/"`. This unlocks `Line2`/`LineMaterial` (crisp, width-controllable, gradient edges — native GL lines are an ugly 1px on white) and the postprocessing passes. ES-module imports are all-or-nothing: one missing addon path blanks the *entire* scene (a useful "did the import resolve?" signal — if the scene is blank, suspect the importmap before the scene code).
- **`EffectComposer` needs an `OutputPass` last** for correct colour on white: `THREE.Color('#hex')` decodes to *linear*, and `OutputPass` converts back to sRGB. A plain `ShaderMaterial` with no composer outputs raw sRGB directly — don't double-convert.

### Critical gotchas

1. **Always tie the loop to `.active` via the scaffold's MutationObserver.** A `requestAnimationFrame` loop that runs on hidden slides drains battery and, worse, every un-disposed `WebGLRenderer` holds a live GL context — past ~16 the browser kills the oldest and slides go blank. `mountSlideScene` disposes on deactivate; don't bypass it.
2. **Cap `setPixelRatio` at 2.** Retina/5K report DPR 2–3; uncapped, a full-bleed canvas allocates 9× the fragments and the deck stutters. The scaffold caps it.
3. **Render real HTML in `.gl-content`.** WebGL can fail (GPU blocklisted, reduced motion, renderer errors). The heading + takeaway live in normal HTML above the canvas, so the slide still makes its point with the scene blank. Never put the *only* copy of a fact inside the 3D scene.
4. **Print/PDF mode shows at most a frozen frame.** The `@media print` path reveals all slides, but inactive ones never mounted, so they export blank. For decks meant to become PDF handouts, give every 3D slide a static SVG or text equivalent, or skip 3D on that deck.
5. **3D is relationships, not readings.** If the audience needs to read an exact number off the screen, that's an SVG chart. Reserve 3D for maps, clusters, and flows where motion and depth *add* comprehension.
6. **`aria-hidden="true"` on the canvas, real semantics in the DOM.** Screen readers can't read a point cloud. The canvas is decorative; the heading and `#gl-detail` panel carry the accessible content.
7. **Pin the three.js version in the importmap.** `three@0.160.0`, not `three@latest` — three.js makes breaking changes between minor releases (e.g. the BufferGeometry and color-management migrations), and `latest` will eventually break a deck you shipped months ago.
8. **`NormalBlending`, never `AdditiveBlending` on white.** Additive accumulates to glow on dark and to *nothing* on white — see the light-background rule above. This is the first thing to check when a ported scene renders blank.
9. **Screen-space pick for `InstancedMesh`, not raycasting.** Raycasting tiny instanced spheres silently misses; project to pixels and take the nearest (see "Making a graph navigable"). `THREE.Points` raycasting with a `threshold` is fine; instanced meshes are not.
10. **Settle → recentre → build, in that order.** Settle the force layout before creating `Line2` edges/labels (place once, not per frame); recentre on the centroid so the graph frames evenly instead of clipping a corner. Gravity only approximates centring.
11. **Dispose the composer and its textures too.** A scene using `EffectComposer`/render targets (or a `CanvasTexture` halo) must dispose them alongside the renderer on unmount, or it leaks GPU memory and live contexts toward the ~16 cap.
