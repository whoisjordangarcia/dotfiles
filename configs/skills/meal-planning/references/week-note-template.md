# Week Note Template

Section skeleton for `<recipes-dir>/YYYY-MM-DD Week.md`, where the date is the
**Monday** of the week. Every section below earns its place — they exist because a plan failed
without one. Drop a section only when it genuinely doesn't apply, and say why.

Reference implementations: `2026-08-03 Week.md` (greens focus), `2026-08-17 Week.md` (cut focus).

---

## Required sections, in order

### 1. `# Week of <Month D, YYYY> — <theme>`

An H1 is fine here — the theme adds information the filename doesn't. Open with the two or three
standing inputs this week is optimizing for, and what changed since last week.

### 2. `## Context`

- Household composition + any young child's current age in months
- **The week's date range, with a note that it was verified against `date`**
- Cook model: rolling one-day-ahead, or weekend batch
- Who cooks vs. who only reheats (a caregiver, a partner on a different shift)
- Starch cap, allergy status, any standing exclusions (a paused protein, a disliked dish, where
  a restricted protein is allowed to appear)

### 3. `## Macros & the Deficit` *(only when a diet goal is set)*

- Targets table (maintenance, daily kcal, daily protein) with unconfirmed inputs flagged
- **Per-serving table** — one row per dish: serving basis, kcal, protein, fat, carbs, and
  **`kcal per gram of protein`**, sorted or flagged (under ~15 ✅, over ~25 ⚠️)
- **Daily rollup table** — lunch + dinner are usually the same dish reheated, so *double it*.
  Show what's left for breakfast and snacks. This is where a week breaks.
- The uncovered protein gap, with the cheapest ways to close it
- State plainly that figures come from NYT's own JSON-LD, and whether rice is included

### 4. `## The Greens Ladder` *(only while a food-acceptance goal is active)*

Table: day, dish, which green, the **form the child actually sees**, and the tier. One different
green per day. Escalate only after acceptance; after a hard green, schedule an easy one.
Generalizes to any "get them to accept X" goal — the ladder is the pattern, greens are one instance.

### 5. `## <N>-Day Schedule`

Table of day / lunch / cooked-when / evening cook. Then call out explicitly:
- The protein rotation, in order, and that nothing repeats back-to-back
- How many pots run per evening
- Which nights someone cooks vs. only reheats

### 6. One section per dish

Heading format: `## <Day> <meal> — <Dish Name>` plus `⭐ NEW` if it's never been cooked.

Each dish section carries:
- The **NYT URL**, author, star rating + review count, total time, and
  `Dairy-free ✓ / Egg-free ✓` (or the swap that makes it so)
- **Why this dish is here** — the actual reasoning, not a description
- `> [!warning]` blocks for every adjustment: allergy swaps, chile removal, substitutions
- **Sizing (×N)** with a full scaled ingredient list — the household's amounts, not the recipe's
- Numbered steps, with the **child's pull point** (before salt/spice/chile) as its own step
- **Child notes**: texture, size cuts, choking hazards, salt, what to check for
- **Reheat note** where the dish is being cooked a day ahead

### 7. `## Cook Timeline`

Per evening: what's cooked, active minutes vs. unattended, and what goes in the fridge.
Add a clock-time table only when two appliances run in parallel.

### 8. `## Storage` + `## Container Labels`

Storage table: container / where / how to reheat. Then a fenced code block of **plain-ASCII
labels** — these get written on tape and stuck to tubs, so no emoji, no markdown, short lines.
Every label states the day, the dish, its vegetable, the reheat instruction, the child's mod, and
any `>> WARNING` (beef, pin bones, whole spices, "don't eat this tub today").

### 9. `## Defrost / Dinner / Save-to-Fridge`

Table: night / that night's dinner / how much to save from lunch / what else to cook tonight /
what to defrost. Then call out **the single real deadline** of the week in bold.

### 10. `## Grocery List — <Month> <D> Week`

Shop day, and "favor organic". Subsections **in this order** — it's the walking order of a store:

1. `### ✅ Already in the house — do NOT buy` (table: have / used for)
2. `### Protein` — raw weights, organic, with the day in parens
3. `### Produce` — greens first, with 🥬 markers, then aromatics, then 🧊 frozen
4. `### Pantry` — with ⚠️ on anything easy to buy wrong (whole vs. ground spice, red vs. brown
   lentils, short- vs. long-grain rice, sweet vs. smoked paprika, unsweetened coconut)
5. `### Check If You Have` — oils, vinegars, salt, table condiments
6. `### Weekly Recurring (always buy)` — the household's standing items (milk, eggs, bread,
   yogurts, coffee…). Pull this list from the rulebook, don't reinvent it each week
7. `### Household supplies` — paper goods etc., only when low
8. `### Automated (do NOT add)` — anything on a subscription/auto-ship. **Listing these is a
   real failure mode**: it buys a second delivery of something already arriving

Consolidate quantities across dishes (garlic, ginger, limes, onions) and show the arithmetic:
`Garlic, 2 heads (Tue 5 + Wed 3 + Thu 6 + Fri 6 ≈ 20 cloves)`.

### 11. `## Candidates for Future Weeks`

Verified URLs found but not used, with their real `kcal/g protein` and why they were passed over.
This is what makes the *next* plan fast — never throw this research away.

### 12. `## After the week — record this`

An empty table to fill in: which greens were accepted, which dishes are worth repeating, whether
a new protein earned a rotation slot. This sets where the next week starts.

### 13. `## Backlinks`

```markdown
→ [[Cooking]]
→ Previous: [[<prev week note>]]
→ Macros: [[Cutting Toolkit — Free Flavor and Protein]]
→ Rules: the rulebook (role 2)
```

---

## Callout conventions

| Callout | Used for |
|---|---|
| `> [!warning]` | Allergy swaps, the beef rule, chile in a base, choking hazards, deadlines |
| `> [!important]` | Substitutions that are not optional |
| `> [!tip]` | Technique that changes the outcome; the metric that matters |
| `> [!success]` | Something that got structurally better vs. last week |
| `> [!note]` | Context worth knowing that changes no action |

Emoji carry meaning and should stay consistent: 🥬 leafy green · 🥩 beef (rule applies) ·
🧊 frozen · ⭐ NEW dish · 🔁 repeat-worthy · ⚠️ read before acting · ✅ verified good ·
🔴 breaks the plan.
