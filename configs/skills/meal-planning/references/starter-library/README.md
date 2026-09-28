# Starter Library — a seed, not the user's library

154 recipe notes, filed into a subfolder per protein lane. **Copy this into the user's
`<recipes-dir>/Library/` on first run**, then leave it alone — from that point the *user's* copy
is the live one, because it's where cook logs, ratings and household adjustments accumulate.

## What each note holds

Frontmatter (`protein`, `kcal_per_g_protein`, `greens`, `allergens`, plus empty `cooked` and
`rating`), a facts table, and three sections the user fills in over time: **Household
adjustments**, **Cook log**, and a one-line command to fetch ingredients and steps.

**No recipe text.** Steps stay at the source and pull on demand:

```bash
python3 <skill-dir>/recipe-scrape.py recipe <url>
```

That keeps 154 files from going stale when a source recipe is edited, and it's the reason the
notes are worth having at all — they hold *the user's* history, which exists nowhere else.

## Regenerating

```bash
python3 <skill-dir>/recipe-scrape.py notes "<recipes-dir>/Library" urls.txt
```

**Never overwrites an existing note**, so re-running after cook logs have been written only adds
what's new.

## Lane depth — read this before planning

| Lane | Count | |
|---|---|---|
| chicken | 56 | ⚠️ over-represented — weeks drift here unless pushed back |
| tofu | 21 | |
| beef | 18 | usually restricted to evenings/weekends |
| salmon | 17 | |
| vegetarian | 12 | |
| fish | 11 | |
| legume | 9 | |
| turkey · egg | 3 each | ⚠️ too thin to fill a weekly slot without repeating |
| shrimp | 2 | ⚠️ |
| pork · lamb | 1 each | ⚠️ |

These counts reflect **one household's taste**. Build the user's own library from recipes they've
already saved as soon as there are any, and treat this as a fallback or a way to top up a lane
too thin to fill a week.
