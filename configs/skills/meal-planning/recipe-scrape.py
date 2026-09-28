#!/usr/bin/env python3
"""Scrape recipes from any site that publishes schema.org Recipe JSON-LD.

That is most of the recipe web — NYT Cooking, Serious Eats, AllRecipes, Bon Appetit,
and any WordPress blog using WP Recipe Maker. The data sits in the public HTML, so
no login is needed for ingredients, steps, ratings, or nutrition.

    recipe-scrape.py nutrition <url> [<url> ...]  # table sorted by kcal per gram of protein
    recipe-scrape.py recipe <url> [<url> ...]     # ingredients + steps
    recipe-scrape.py index urls.txt [more.txt]    # build a rotation index (markdown table)
    recipe-scrape.py add <index.md> <url> [...]   # append new recipes to an existing index
    recipe-scrape.py notes <out-dir> urls.txt     # one note per recipe, foldered by protein
    recipe-scrape.py search "chicken greens"      # NYT Cooking search only

Sites that DON'T emit JSON-LD fall back to a clear error rather than guessing --
paste the ingredients in by hand instead of trusting a scraped approximation.

Two gotchas are handled here. Do not re-derive them:
  1. The tag is <script type="application/ld+json" data-next-head="">. A regex ending
     in '">' matches zero recipes. Match [^>]*> instead.
  2. Without --compressed, curl returns gzip and decoding raises
     "'utf-8' codec can't decode byte 0x8b in position 1".
"""

import json
import pathlib
import re
import subprocess
import sys

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0 Safari/537.36")

# gotcha #1: data-next-head lives inside the tag, so don't anchor on '">'
LD_JSON = re.compile(r'<script type="application/ld\+json"[^>]*>(.*?)</script>', re.S)


def fetch(url):
    # gotcha #2: --compressed, or gzip bytes blow up the utf-8 decode
    return subprocess.run(
        ["curl", "-sL", "--compressed", "-A", UA, url],
        capture_output=True, text=True, errors="replace", timeout=45,
    ).stdout


def recipes(html):
    """Yield every schema.org Recipe object embedded in the page.

    Handles the three shapes seen in the wild: a bare object, a top-level array, and
    a Yoast/WPRM-style {"@graph": [...]} wrapper. Deduped by name -- plenty of sites
    emit the same recipe twice in separate script tags.
    """
    seen = set()
    for block in LD_JSON.findall(html):
        try:
            data = json.loads(block)
        except json.JSONDecodeError:
            continue
        stack = list(data) if isinstance(data, list) else [data]
        while stack:
            obj = stack.pop(0)
            if not isinstance(obj, dict):
                continue
            if isinstance(obj.get("@graph"), list):
                stack += obj["@graph"]
            if "Recipe" in str(obj.get("@type", "")):
                key = str(obj.get("name", "")).strip().lower()
                if key not in seen:
                    seen.add(key)
                    yield obj


def num(value):
    """'22.3 grams' -> 22.3. Nutrition values are strings with units."""
    match = re.search(r"[\d.]+", str(value))
    return float(match.group()) if match else None


def minutes(iso):
    """PT0H35M -> '35 min'. NYT mixes PT35M and PT0H35M in the same field."""
    if not iso:
        return "?"
    h = re.search(r"(\d+)H", iso)
    m = re.search(r"(\d+)M", iso)
    total = int(h.group(1)) * 60 if h else 0
    total += int(m.group(1)) if m else 0
    return f"{total} min" if total else "?"


def cmd_search(query):
    html = fetch("https://cooking.nytimes.com/search?q=" + query.replace(" ", "+"))
    slugs = sorted(set(re.findall(r"/recipes/\d{6,}-[a-z0-9-]*", html)))
    if not slugs:
        sys.exit(f"no results for {query!r} (search markup may have changed)")
    for slug in slugs:
        print("https://cooking.nytimes.com" + slug)


def cmd_nutrition(urls):
    rows = []
    for url in urls:
        for r in recipes(fetch(url)):
            n = r.get("nutrition") or {}
            kcal, protein = num(n.get("calories")), num(n.get("proteinContent"))
            rows.append({
                "ratio": round(kcal / protein, 1) if kcal and protein else None,
                "kcal": kcal, "protein": protein,
                "fat": num(n.get("fatContent")), "carbs": num(n.get("carbohydrateContent")),
                "name": r.get("name", "?").strip(),
                "yield": r.get("recipeYield"), "time": minutes(r.get("totalTime")),
                "rating": (r.get("aggregateRating") or {}).get("ratingValue"),
                "count": (r.get("aggregateRating") or {}).get("ratingCount"),
                "url": url,
            })
    if not rows:
        sys.exit("no recipe JSON-LD found — check the URL, or the ld+json regex has rotted")

    # under ~15 is good on a cut, over ~25 is a red flag
    rows.sort(key=lambda r: r["ratio"] if r["ratio"] is not None else 999)
    print(f"{'kcal/gP':>8}  {'kcal':>5} {'prot':>5} {'fat':>4} {'carb':>5}  "
          f"{'rating':>12}  {'time':>7}  yield / name")
    for r in rows:
        flag = "" if r["ratio"] is None else " OK" if r["ratio"] < 15 else " !!" if r["ratio"] > 25 else ""
        stars = f"{r['rating']}*/{r['count']}" if r["rating"] else "-"
        print(f"{str(r['ratio']):>8}{flag:<3} {str(round(r['kcal'])) if r['kcal'] else '?':>5} "
              f"{str(round(r['protein'])) + 'g' if r['protein'] else '?':>5} "
              f"{str(round(r['fat'])) if r['fat'] else '?':>4} "
              f"{str(round(r['carbs'])) if r['carbs'] else '?':>5}  {stars:>12}  "
              f"{r['time']:>7}  {r['yield']} / {r['name']}")


# Rotation tagging. Order matters — first match wins, so the more specific protein
# (which drives the rotation) beats a generic one that's only a garnish or a broth.
PROTEINS = [
    ("beef", r"\bground beef|\bbeef\b|chuck|brisket|sirloin|flank|short rib|steak\b"),
    ("lamb", r"\blamb\b"), ("pork", r"\bpork|bacon|chorizo|pancetta|sausage\b"),
    ("salmon", r"\bsalmon\b"), ("shrimp", r"\bshrimp|prawn\b"),
    ("fish", r"\bcod\b|halibut|tilapia|snapper|sea bass|trout|\bfish fillet|anchov"),
    ("turkey", r"\bturkey\b"), ("chicken", r"\bchicken\b"),
    ("tofu", r"\btofu|tempeh|edamame\b"),
    ("legume", r"\blentil|chickpea|black bean|white bean|cannellini|kidney bean"),
    ("egg", r"\beggs?\b"), ("vegetarian", r"."),
]
GREENS = (r"spinach|kale|chard|collard|bok choy|arugula|escarole|cabbage|broccoli rabe|"
          r"mustard greens|watercress|lettuce|asparagus|broccoli|green bean|snow pea|pea shoots")
# Garnish-or-optional dairy is still dairy for an allergy — flag it, let a human judge.
DAIRY = r"butter|\bmilk\b|cream|cheese|parmesan|yogurt|feta|paneer|ricotta|mozzarella|creme fraiche|ghee"
EGG = r"\beggs?\b|mayonnaise|egg noodle|meringue"


def tag(ingredients):
    blob = " ".join(ingredients).lower()
    # coconut milk / cream and almond milk are not dairy — strip before testing
    dairy_blob = re.sub(r"(coconut|almond|oat|soy|cashew|rice)[ -](milk|cream|yogurt|butter)", "", blob)
    dairy_blob = re.sub(r"(peanut|almond|nut|cocoa|shea) butter", "", dairy_blob)
    protein = next(name for name, pat in PROTEINS if re.search(pat, blob))
    greens = sorted(set(re.findall(GREENS, blob)))
    return {
        "protein": protein,
        "greens": ", ".join(greens[:3]) or "-",
        "dairy": bool(re.search(DAIRY, dairy_blob)),
        "egg": bool(re.search(EGG, blob)),
    }


def author(recipe):
    """author is a dict, a list of dicts, or a bare string depending on the site."""
    a = recipe.get("author")
    if isinstance(a, list):
        a = a[0] if a else None
    if isinstance(a, dict):
        a = a.get("name")
    return str(a) if a else ""


def yield_(recipe):
    """recipeYield is often a list like ['6', '6 about 1.5 cups each'] -- take the longest."""
    y = recipe.get("recipeYield")
    if isinstance(y, list):
        y = max((str(i) for i in y), key=len, default="")
    return str(y) if y else ""


def steps(recipe):
    """Flatten recipeInstructions. Many sites wrap steps in HowToSection groups."""
    out = []

    def walk(node):
        if isinstance(node, list):
            for item in node:
                walk(item)
        elif isinstance(node, dict):
            if node.get("@type") == "HowToSection" or "itemListElement" in node:
                walk(node.get("itemListElement", []))
            elif node.get("text"):
                out.append(node["text"].strip())
        elif isinstance(node, str) and node.strip() and node != "None":
            out.append(node.strip())

    walk(recipe.get("recipeInstructions", []))
    return out


def cmd_index(paths):
    """Build a sortable rotation index from a file of URLs (one per line).

    Stores metadata only — title, link, macros, tags. Full text stays at the source
    and is pulled on demand with `recipe <url>` for the handful actually being cooked.
    """
    from concurrent.futures import ThreadPoolExecutor

    urls = []
    for p in paths:
        with open(p) as fh:
            urls += [ln.strip() for ln in fh if ln.strip().startswith("http")]
    urls = sorted(set(urls))
    print(f"# fetching {len(urls)} recipes…", file=sys.stderr)

    with ThreadPoolExecutor(max_workers=8) as pool:
        rows = [r for r in pool.map(scrape_one, urls) if r]
    print(f"# got {len(rows)} of {len(urls)}", file=sys.stderr)
    print(render(rows))


def scrape_one(url):
    """One URL -> one index row, or None if the page has no usable Recipe JSON-LD."""
    try:
        for r in recipes(fetch(url)):
            n = r.get("nutrition") or {}
            kcal, prot = num(n.get("calories")), num(n.get("proteinContent"))
            t = tag(r.get("recipeIngredient", []))
            return {
                "name": r.get("name", "?").strip(), "url": url,
                "kcal": kcal, "prot": prot,
                "ratio": round(kcal / prot, 1) if kcal and prot else None,
                "time": minutes(r.get("totalTime")),
                "rating": (r.get("aggregateRating") or {}).get("ratingValue"),
                "count": (r.get("aggregateRating") or {}).get("ratingCount") or 0,
                **t,
            }
    except Exception:
        return None


# Rotation lanes, in the order a week is usually built: fish and poultry first
# (they carry the best protein-per-calorie), red meat last since it is often
# restricted to evenings or weekends.
LANE_ORDER = ["chicken", "turkey", "salmon", "fish", "shrimp", "tofu", "legume",
              "vegetarian", "egg", "pork", "beef", "lamb"]


def render(rows):
    """Group into one section per protein lane -- that IS the rotation."""
    from collections import defaultdict
    lanes = defaultdict(list)
    for r in rows:
        lanes[r["protein"]].append(r)

    out = []
    order = [l for l in LANE_ORDER if l in lanes] + sorted(set(lanes) - set(LANE_ORDER))
    out.append("## Lane depth\n")
    out.append("| Protein | Count | |")
    out.append("|---|---|---|")
    for lane in order:
        n = len(lanes[lane])
        note = ("⚠️ too thin to fill a weekly slot without repeating" if n <= 3
                else "⚠️ over-represented — weeks drift here unless pushed back"
                if n > len(rows) * 0.3 else "")
        out.append(f"| [{lane}](#{lane}) | {n} | {note} |")
    good = sum(1 for r in rows if r["ratio"] is not None and r["ratio"] < 15)
    flagged = sum(1 for r in rows if r["dairy"] or r["egg"])
    out.append(f"\n**{good} of {len(rows)}** are under 15 kcal/g protein. "
               f"**{flagged}** carry a dairy or egg flag.\n")

    for lane in order:
        group = sorted(lanes[lane], key=lambda r: r["ratio"] if r["ratio"] is not None else 999)
        out.append(f"\n## {lane}\n")
        out.append("| Recipe | kcal/gP | kcal | Prot | Time | Rating | Greens | ⚠️ |")
        out.append("|---|---|---|---|---|---|---|---|")
        for r in group:
            warn = " ".join(x for x in ("dairy" if r["dairy"] else "",
                                        "egg" if r["egg"] else "") if x) or "—"
            ratio = ("-" if r["ratio"] is None else f"**{r['ratio']}**"
                     if r["ratio"] < 15 else str(r["ratio"]))
            stars = f"{r['rating']}★/{r['count']}" if r["rating"] else "-"
            out.append(f"| [{r['name']}]({r['url']}) | {ratio} | "
                       f"{round(r['kcal']) if r['kcal'] else '-'} | "
                       f"{str(round(r['prot'])) + 'g' if r['prot'] else '-'} | {r['time']} | "
                       f"{stars} | {r['greens']} | {warn} |")
    return "\n".join(out)


def cmd_add(index_path, urls):
    """Append new recipes to an existing index, skipping ones already listed.

    Extraction is metadata only -- title, link, macros, tags. Full ingredients and
    steps stay at the source and get pulled on demand with `recipe <url>`.
    """
    from concurrent.futures import ThreadPoolExecutor
    path = pathlib.Path(index_path)
    existing = path.read_text() if path.exists() else ""
    fresh = [u for u in dict.fromkeys(urls) if u not in existing]
    skipped = len(set(urls)) - len(fresh)
    if skipped:
        print(f"# {skipped} already in the index, skipping", file=sys.stderr)
    if not fresh:
        sys.exit("# nothing new to add")

    with ThreadPoolExecutor(max_workers=8) as pool:
        rows = [r for r in pool.map(scrape_one, fresh) if r]
    failed = [u for u in fresh if u not in {r["url"] for r in rows}]
    for u in failed:
        print(f"# FAILED (no Recipe JSON-LD, or the site blocked the fetch): {u}", file=sys.stderr)
    if not rows:
        sys.exit("# nothing extracted")

    print(f"# adding {len(rows)} recipe(s)", file=sys.stderr)
    print(render(rows))
    print(f"\n# ^ paste into {index_path}, or re-run `index` over the full URL list to "
          f"regenerate it sorted", file=sys.stderr)


SAFE = str.maketrans({c: "-" for c in '/\\:*?"<>|#^[]'})


def cmd_notes(outdir, paths):
    """One markdown note per recipe, filed into a subfolder per protein lane.

    Layout: <out-dir>/<protein>/<Dish Name>.md -- so the folder tree IS the rotation.

    Deliberately NOT a copy of the recipe. The note holds what makes it findable and
    sortable (macros, lane, flags) plus the user's own history -- which exists nowhere
    else. Ingredients and steps stay at the source, one `recipe <url>` away.
    """
    from concurrent.futures import ThreadPoolExecutor
    out = pathlib.Path(outdir)
    out.mkdir(parents=True, exist_ok=True)

    urls = []
    for f in paths:
        with open(f) as fh:
            urls += [ln.strip() for ln in fh if ln.strip().startswith("http")]
    urls = sorted(set(urls))
    print(f"# fetching {len(urls)}…", file=sys.stderr)
    with ThreadPoolExecutor(max_workers=8) as pool:
        rows = [r for r in pool.map(scrape_one, urls) if r]

    written = skipped = 0
    for r in rows:
        name = r["name"].translate(SAFE).strip()
        lane = out / r["protein"]
        lane.mkdir(exist_ok=True)
        path = lane / f"{name}.md"
        if path.exists():
            # never clobber a note the user has added their own cook log to
            skipped += 1
            continue
        ratio = r["ratio"]
        verdict = ("lean — good on a cut" if ratio and ratio < 15
                   else "expensive per gram of protein" if ratio and ratio > 25
                   else "middling") if ratio else "no nutrition data"
        flags = [x for x in ("dairy" if r["dairy"] else "", "egg" if r["egg"] else "") if x]
        greens = r["greens"] if r["greens"] != "-" else ""
        fm = [
            "---",
            f'title: "{r["name"]}"',
            f'source: {r["url"]}',
            f'protein: {r["protein"]}',
            f'kcal: {round(r["kcal"]) if r["kcal"] else ""}',
            f'protein_g: {round(r["prot"]) if r["prot"] else ""}',
            f'kcal_per_g_protein: {ratio if ratio else ""}',
            f'time: "{r["time"]}"',
            f'rating_source: {r["rating"] or ""}',
            f'greens: [{greens}]',
            f'allergens: [{", ".join(flags)}]',
            "tags: [recipe, " + r["protein"] + "]",
            "cooked: []",
            "rating: ",
            "---",
            "",
            f"**[Open the recipe]({r['url']})** — {r['time']}"
            + (f" · {r['rating']}★ source rating" if r["rating"] else ""),
            "",
            "| | |",
            "|---|---|",
            f"| Protein lane | **{r['protein']}** |",
            f"| Per serving | {round(r['kcal']) if r['kcal'] else '?'} kcal · "
            f"{round(r['prot']) if r['prot'] else '?'} g protein |",
            f"| kcal per g protein | **{ratio if ratio else '?'}** — {verdict} |",
            f"| Greens | {greens or 'none — bolt one on'} |",
            f"| ⚠️ Allergens detected | {', '.join(flags) if flags else 'none detected'}"
            + (" — **verify, this is a regex**" if flags else "") + " |",
            "",
            "## Ingredients & steps",
            "",
            "Not copied here — pull them when you're actually cooking:",
            "",
            "```bash",
            f"python3 <skill-dir>/recipe-scrape.py recipe {r['url']}",
            "```",
            "",
            "## Household adjustments",
            "",
            "<!-- allergy swaps, chile removed from the base, toddler pull point, scaling -->",
            "",
            "## Cook log",
            "",
            "| Date | Rating | Notes |",
            "|---|---|---|",
            "| | | |",
            "",
        ]
        path.write_text("\n".join(fm))
        written += 1
    print(f"# wrote {written} note(s) to {outdir}"
          + (f", skipped {skipped} that already exist" if skipped else ""), file=sys.stderr)


def cmd_recipe(urls):
    for url in urls:
        for r in recipes(fetch(url)):
            print(f"\n=== {r.get('name')}")
            meta = [x for x in (author(r), yield_(r), minutes(r.get("totalTime"))) if x]
            print(" | ".join(meta) + f" | {url}")
            print("\nINGREDIENTS")
            for i in r.get("recipeIngredient", []):
                print("  -", i)
            print("\nSTEPS")
            for n, text in enumerate(steps(r), 1):
                print(f"{n}. {text}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    action, args = sys.argv[1], sys.argv[2:]
    if action == "search":
        cmd_search(" ".join(args))
    elif action == "nutrition":
        cmd_nutrition(args)
    elif action == "recipe":
        cmd_recipe(args)
    elif action == "index":
        cmd_index(args)
    elif action == "add":
        cmd_add(args[0], args[1:])
    elif action == "notes":
        cmd_notes(args[0], args[1:])
    else:
        sys.exit(__doc__)
