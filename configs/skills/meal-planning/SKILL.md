---
name: meal-planning
description: Use when the user asks to plan meals, "do next week's groceries", build a weekly meal plan, make a grocery or shopping list, pick recipes, or asks what to cook this week. Also for logging what got cooked, recording whether the toddler accepted a food, or updating meal preferences and allergies.
---

# Meal Planning

## Overview

A weekly meal plan is **one artifact that fans out into several systems**. The plan document is
the source of truth; the shopping list, the calendar reminders, and the stored preferences are
all derived from it. Getting the fan-out right is most of the job — a plan nobody can shop from
or cook from is not a plan.

**Core principle: the constraints are hard rules, and they live in files, not in your head.**
Read them before planning. Every one of them got written because a plan broke without it.

## Read These First — Non-Negotiable

Locate these by **role**, not by path — every setup puts them somewhere different. Establish the
paths once in Step 0 and record them in the rulebook.

| Role | How to find it | What it holds |
|---|---|---|
| **The rulebook** | An auto-loading `CLAUDE.md` / `AGENTS.md` in the recipes directory | **Allergies, who-can't-eat-what, portion sizing, protein rotation, diet goals, grocery-list format, the concrete IDs for the shopping app and calendar** |
| **Recent week plans** | Last 2–3 dated plans in the recipes directory | What was cooked recently — **check to avoid repeats** |
| **Long-lived references** | Named notes in the recipes directory | Macro toolkits, pantry staples, technique notes |
| **Preference memory** | The agent's memory directory + index | Facts about people that outlive any one week |

**Placeholders used throughout this skill** — resolve each from the rulebook on the first run,
never hardcode one:

| Placeholder | What it stands for |
|---|---|
| `<notes-dir>` | The root of the user's notes/vault |
| `<recipes-dir>` | Where meal plans and recipes live inside it |
| `<skill-dir>` | This skill's own directory, wherever it was installed |

```bash
# find the rulebook and the recent plans in an unfamiliar setup
fd -i 'claude.md|agents.md' <recipes-dir>
ls -t <recipes-dir> | head -5
```

**Never plan a meal from memory.** An allergy set you guessed at produces a dangerous plan. If you
can't find a rulebook, that means Step 0 hasn't been done — do it before picking a single recipe.

## Step 0 — Establish the household before planning anything

**Portion sizes, protein rotation, and half the safety rules are all functions of who is eating.**
Plan without this and every quantity on the grocery list is a guess.

**If the rulebook has no household block** (a fresh setup, or a first run), ask all of
this in **one** `AskUserQuestion` batch, then **write the answers into that file** so it never has
to be asked again:

| Ask | Why it changes the plan |
|---|---|
| **Where is your recipes / meal-planning directory?** | Resolves `<recipes-dir>`. **Ask this first** — nothing else can be looked up until it's known |
| **Where is the notes root it sits in?** | Resolves `<notes-dir>` — needed to harvest saved recipe links and to find the session log |
| **How many adults eat the main meal?** | Sets raw protein weight — the single biggest list quantity |
| **Any kids? What age?** | Under ~4 needs pull-before-salt, size cuts, choking-hazard checks, and a separate texture plan |
| **Any allergies or intolerances?** | **Hard constraint.** Drives every recipe filter and every substitution |
| **Which proteins are in play?** — chicken, beef, pork, lamb, salmon, other fish, shellfish, turkey, tofu/tempeh, beans/lentils, eggs | **Defines the rotation.** A protein that's out (vegetarian, no pork, shellfish allergy, a paused item) removes a whole lane, and the remaining lanes have to cover every day without repeating |
| **Any dislikes or hard no's?** | Softer, but a disliked dish is a wasted cook (e.g. no meatballs here) |
| **Does anyone eat separately?** — a caregiver, a shift worker, someone who skips a protein | Creates split-cook rules; this is where the no-beef-at-lunch rule came from |
| **Are lunch and dinner the same dish reheated?** | Doubles both the portions **and** the daily calorie math |
| **Any diet goal?** — cutting, bulking, maintenance, a protein target | Turns on the macros section and the `kcal/g protein` column |
| **Cooking appliances + effort tolerance** | Instant Pot / slow cooker / sheet pan changes which recipes are even candidates |
| **What day does the week start?** — and what day do you shop? | Names the week note, sets which day is cook-ahead vs. fridge-clearing, anchors every calendar event |
| **Where do standalone recipes get saved?** | A keeper recipe outlives the week it was cooked in — it needs a home that isn't a dated note |

> [!important] The paths go to **memory**, everything else goes to the **rulebook**
> This looks inconsistent until you try to bootstrap it: the rulebook lives *inside* the recipes
> directory, so **you cannot read it until you already know where that directory is.** Memory
> loads automatically every session with no lookup, which makes it the only store that can hold
> the pointer.
>
> So, exactly two things in memory: **`<notes-dir>` and `<recipes-dir>`.** Everything
> else — allergies, portions, proteins in play, week-start day, shopping-app and calendar IDs —
> belongs in the rulebook, where it sits next to the plans it governs.
>
> **On a later run, if the placeholders don't resolve, the memory is missing or stale.** Ask once
> and re-save rather than guessing at a path or scanning the filesystem for something recipe-shaped.

**Ask these two once and write them down** — they're setup, not per-week decisions:

- **Week start day.** Default `Monday`, so the plan is `<recipes-dir>/YYYY-MM-DD Week.md` dated to
  that Monday and the shop lands the day before. If the answer is Sunday or Saturday, the file
  date, the schedule table, and the "fridge-clearing at the end" slot all shift with it — don't
  leave a Monday-shaped plan under a Sunday filename.
- **Standalone recipe location.** Default `<recipes-dir>/<Dish Name>.md`. A dish earns its own note
  when it gets repeated, gets rated, or gets modified enough that the week note's version is
  wrong. Everything else stays inside the week note — **don't split a dish out on first cook.**

### First-run setup checklist

Do these **once**, in order, before the first plan. Every one of them is a thing that otherwise
gets re-derived (badly) every single week.

- [ ] **Ask the intake above in one batch.** Don't drip the questions across the session.
- [ ] **Save the directory paths to memory (role 4) — not the rulebook.** See the bootstrap note
      below. One memory file with `<notes-dir>` and `<recipes-dir>` resolved.
- [ ] **Write everything else into the rulebook** — household block, allergies, proteins in play,
      portion rule, week-start day, and the concrete IDs for the shopping app and calendar.
- [ ] **Record person-facts to memory** (role 4): allergies, dislikes, diet goals. These outlive
      this project; the rulebook covers rules, memory covers people.
- [ ] **Check the calendar tooling** — `command -v gws`. Offer to install, or skip role 6 and say so.
- [ ] **Build the rotation index** (role 8) — the step below. Without it the first several weeks
      are searched from scratch and drift toward whatever the search engine surfaces.
- [ ] **Report the lane depth back to the user.** See the warning under the rotation index — the
      shape of their pool is a planning constraint they can't see from inside one week.

**On every run afterward, re-confirm only the deltas** — one quick question, not the whole intake:
*guests this week, anyone traveling, is a regular eater away, did the headcount change?* A single
guest at dinner moves the protein buy by half a pound. Re-run the rotation index only when a batch
of new recipes has been saved, or a slug has gone dead.

### Portion math — derive it, don't memorize it

```
raw protein (lb) = 0.5 × adults  +  0.15 × young kids     … per meal
  + same again          if the same cook also feeds a separate dinner
  + 0.5 lb              if it also carries into another day's dish
```

Buy the **raw** weight — proteins lose ~25% cooking. Tofu is denser: 2–3 blocks (14–16 oz) covers
lunch + dinner. Rice cap: **1 cup dry per meal**, and flag any dish that is rice-*based* by design.

> Sanity check against this household (3 adults + 1 toddler): `0.5×3 + 0.15 = 1.65 ≈ **1.5 lb**`
> for lunch alone, `≈ **2.5 lb**` when the same cook feeds dinner. Those are exactly the numbers in
> the rulebook — if your arithmetic doesn't reproduce them, you've misread the headcount.

## The Pipeline

0. **Step 0 above** — household and stores known and current.
1. **Date-check.** Run `date`. Confirm which date the configured **week-start day** actually falls
   on — a plan has silently drifted a day before. Name the week plan from that date.
2. **Read the rulebook + the last 2–3 week plans.** Extract: what proteins ran, which recipes are
   too recent to repeat, what's flagged as unfinished. Then **shortlist from the rotation index**
   (role 8) rather than searching from scratch — it's already filtered and sorted.
3. **Ask what you can't derive.** Fridge/freezer inventory, whether last week actually got cooked,
   how the kid reacted, any theme. Batch these into one `AskUserQuestion` — don't drip them.
4. **Pick recipes and scrape real numbers.** NYT Cooking preferred. Use `recipe-scrape.py` (below) —
   **never estimate calories or protein.**
5. **Write the week plan** — see `references/week-note-template.md` for the section skeleton.
6. **Show the grocery list, then offer the fan-out.** Roles 5 and 6 write outside the plan
   document — **ask first, every time.** Record any new durable preference to memory (role 4).
7. **Log and commit** if there's a session log and the plan lives in git. Commit **locally**;
   don't push unless the user's own instructions say to.

## Where Things Get Saved — the persistence map

A meal plan produces **several kinds of output with different lifespans.** Route each by lifespan, not
by convenience. The *roles* below are fixed; the tools filling them are per-setup — establish them
in Step 0 and write the answers down.

| # | Role | Lifespan | Ask in Step 0 | Reasonable default |
|---|---|---|---|---|
| 1 | **Week plan** — dishes, macros, steps, grocery list | One week, then archive | "Where do weekly plans go?" | `<recipes-dir>/YYYY-MM-DD Week.md`, dated to the week-start day |
| 2 | **Rulebook** — constraints that shape *every* plan | Permanent, read every time | "Is there a file that auto-loads for cooking tasks?" | A `CLAUDE.md` / `AGENTS.md` in the recipes directory |
| 3 | **Keeper recipes** — a dish that outlived its week | Permanent, looked up by name | "Where do standalone recipes go?" | `<recipes-dir>/<Dish Name>.md`, only once repeated or rated |
| 4 | **Cross-session preferences** — who the people are | Permanent, spans projects | — | The agent's memory directory + its index |
| 5 | **The shopping list** — the thing carried into a store | Until shopped | **"Which app or list do you shop from?"** | Whatever they already use. **Never invent one** |
| 6 | **Time-bound reminders** — defrost, cook blocks, shop run | Until the event passes | **"Which calendar, and is it shared?"** | A dedicated cooking calendar, **never the primary one** |
| 7 | *(optional)* **Session log** | Dated journal | "Do you keep daily notes?" | A daily note that backlinks to the week plan |
| 8 | **Rotation index** — the sortable pool to pick from | Rebuilt on demand | — | `<recipes-dir>/Rotation Index.md`, generated by `recipe-scrape.py index` |

> [!important] Roles 5 and 6 are integrations — ask, never assume
> The shopping list lives wherever the household **already** shops from: a tasks app, a shared
> notes list, a store's own app, a printed page. The calendar may be shared with people who
> didn't ask for invites. Both write **outside** the plan document, so:
> **build the list first, show it, then ask before pushing it anywhere.**

### Role 5b (optional) — pushing the list to an online grocery cart

Some setups order groceries online (Whole Foods/Amazon, Instacart, a store's own site) instead of
carrying a checklist in. Treat this as an **extra delivery target for the same list**, never a
replacement for showing it first.

> [!warning] Precondition: a logged-in browser session. There is no way around this.
> A cart lives behind the user's account, so a fresh headless browser is useless — it has no
> session, no delivery address, and no store selected. You must drive **the user's real browser
> profile**, which means:
>
> 1. Check what's actually available before promising anything — is there a browser-automation
>    tool, and can it attach to a real profile rather than launching a clean one?
> 2. **Attaching usually requires relaunching the browser with a remote-debugging port**, which
>    closes their tabs. **Ask before doing it.** Browsers also tighten this between releases, so a
>    recipe that worked last month may fail today — verify, don't assume.
> 3. If none of that is available, **say so plainly and hand over the list instead.** A grocery
>    list the user pastes in themselves is a fine outcome; a half-filled cart is not.

**Order of operations — the list is approved before anything is added:**

1. Build and **show** the grocery list. Get an explicit go-ahead.
2. Confirm the right store and delivery address are already selected in the session.
3. Add items one at a time, **reporting the actual product matched** for each.
4. Report every line that didn't match, or matched badly.
5. **STOP. Never check out.** Adding to a cart is reversible; placing an order is not. The user
   places it — they need to see substitutions, delivery windows, and the total.

> [!important] The list and the catalog do not speak the same language
> Every line is a fuzzy match plus a unit conversion, and this is where carts go wrong quietly:
>
> - **Quantities don't transfer.** "Collard greens, 2 bunches" is one search result and a quantity
>   of 2 — but "mature spinach, 1½ lb" might be three 8 oz bunches or one tub. **Convert
>   deliberately and say what you did.**
> - **Sold-by-weight items** (meat, fish, loose produce) price per lb, so the cart total is an
>   estimate and the count field may mean *packages*, not pounds.
> - **"Organic" is a filter, not a word.** Searching `organic chicken thighs` often returns
>   conventional results ranked first. Verify the product actually says organic.
> - **The specific form matters** — the plan says short-grain rice, red lentils, sweet paprika,
>   unsweetened coconut, mature spinach for a reason. A near-match is a wrong ingredient.
> - **Skip the "already in the house" and "automated subscription" sections entirely.** Adding
>   auto-shipped items is the classic double-order.
>
> When a match is uncertain, **leave it out and list it as needing a human** rather than adding a
> guess. An item the user adds themselves costs 20 seconds; a wrong one costs a meal.

**Calendar (role 6) — check for a CLI before offering it.** Google Calendar needs the `gws` CLI:

```bash
command -v gws || echo "gws not installed"
export GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file   # always — a locked keyring makes gws DELETE its own credentials
gws calendar calendars list
```

- **`gws` present** → offer the events, writing to the dedicated cooking calendar only.
- **`gws` missing** → **ask once** whether they want to install it
  (`uv tool install google-workspace-cli`, then `gws auth login`). If they decline or don't use
  Google Calendar, **skip role 6 entirely and say so** — put the defrost deadlines in the plan's
  own reminder table instead. A missing calendar is not a blocker; a defrost that nobody was told
  about is. **Never silently drop the reminders because the tooling wasn't there.**

### Which store gets what

| Fact | Goes to | Because |
|---|---|---|
| This week's dishes, macros, steps, grocery list | **Week plan** (1) | Dated, used once, archived |
| A rule that will apply to every future week | **Rulebook** (2) | Loads automatically, so it can't be forgotten |
| A dish worth cooking again, with its modifications | **Keeper recipe** (3) | Found by name, not by date |
| A durable fact about a *person* — allergy, dislike, goal | **Memory** (4) + its index | Survives across projects and sessions |
| The list to actually shop from | **Shopping list app** (5), grouped by store section | It's a checklist, not a document |
| Defrost reminders, cook blocks, shop runs | **Cooking calendar** (6) | Surfaces to the whole household |
| What happened this session | **Session log** (7) | Journal, not reference |
| The pool of candidate recipes to pick from | **Rotation index** (8) | Regenerable — never hand-edit it |

**Don't duplicate.** A rule in the rulebook does not also go in memory. Rules that shape every
plan → rulebook. Facts about *people* → memory. A dish only graduates from the week plan to its
own note **after** it's been cooked and rated — not on first cook.

<details>
<summary><b>Worked example — a typical filled-in map</b></summary>

| Role | Filled by |
|---|---|
| 1 · Week plan | `<recipes-dir>/YYYY-MM-DD Week.md` |
| 2 · Rulebook | `<recipes-dir>/CLAUDE.md` — allergies, restricted proteins, portion rule, and the IDs for roles 5 and 6 |
| 3 · Keeper recipes | `<recipes-dir>/<Dish Name>.md`, plus long-lived references like a macros toolkit |
| 4 · Preferences | the agent's memory directory + its index file |
| 5 · Shopping list | a tasks app → a "Groceries" project with **headings by store section** (Protein / Produce / Pantry / Recurring). Route each item to its heading — a flat dump is unshoppable |
| 6 · Calendar | a **dedicated** cooking calendar, never the primary one, **never with attendees** |
| 7 · Session log | `<notes-dir>/<daily-notes-dir>/YYYY-MM-DD <topic>.md`, backlinked to the week plan |
| 8 · Rotation index | `<recipes-dir>/Rotation Index.md` |

**Concrete values never live in this skill.** Real directory paths, the tasks-app project UUID and
the calendar ID all belong in the **rulebook** (role 2) — that's the whole job of role 2. Read them
from there at the start of each run. If you find yourself about to hardcode one here, that's the
signal Step 0 was skipped.
</details>

## The Rotation Index — build the pool once, pick from it every week

Searching for recipes from scratch every week is the slow path, and it quietly biases toward
whatever the search engine surfaces. Build a **sortable pool once**, then shortlist from it.

```bash
# harvest every recipe URL already saved anywhere in the notes
rg -o --no-filename 'https?://[^ )]*/recipes?/[a-z0-9-]+' <notes-dir> | sort -u > /tmp/urls.txt
python3 <skill-dir>/recipe-scrape.py index /tmp/urls.txt > "<recipes-dir>/Rotation Index.md"

# later: pull one new recipe off any site and append it
python3 <skill-dir>/recipe-scrape.py add "<recipes-dir>/Rotation Index.md" <url> [<url>…]
```

**Output is grouped into one section per protein lane** — that grouping *is* the rotation. Within
each lane, rows sort by `kcal/g protein`. A lane-depth table sits at the top and auto-flags both
failure modes: a lane at ≤3 recipes **cannot** fill a weekly slot without repeating, and a lane
over 30% of the pool will drag every week toward it.

Each row gets: title, link, **kcal/g protein**, kcal, protein, time, rating, which greens it
carries, and **dairy/egg flags detected from the ingredients**. ~2 minutes for 170 URLs, 8 at a time.

### Adding recipes the user finds on the web

`add` works on **any site publishing schema.org Recipe JSON-LD** — most of the recipe web,
including WordPress blogs (it walks the Yoast `@graph` wrapper) and sites that group steps into
`HowToSection` blocks. It skips URLs already in the index and **prints every URL it failed on**.

> [!warning] Two failure modes, both loud by design
> - **Bot-blocked (HTTP 403).** Several large publishers reject a plain `curl` regardless of
>   user-agent. The URL is reported as failed — **don't quietly drop it.** Fetch it through a
>   browser tool, or ask the user to paste the ingredients.
> - **No JSON-LD at all.** Some blogs publish recipes as prose. The script errors rather than
>   guessing; **a hallucinated ingredient list is worse than no row.** Add it by hand.
>
> Either way, tell the user which URLs didn't make it. A rotation index that silently lost a
> third of its input looks complete and isn't.

> [!important] **Metadata only — never bulk-copy recipe text.**
> The index stores titles, links, macros and tags. Full ingredients and steps stay at the source
> and get pulled on demand (`recipe <url>`) for the handful actually being cooked. That's not only
> the right thing to do with someone else's subscription content — it's the better artifact.
> A rotation needs something *sortable*; 150 archived copies go stale the moment a recipe is edited.

**Two starters ship with this skill**, both seeds to copy in, not the user's own:
`references/starter-rotation-pool.md` (the flat scannable index) and
`references/starter-library/` (the same 154 as one note per recipe, foldered by protein — copy to
`<recipes-dir>/Library/`, then leave it alone; the user's copy is where cook logs accrue).
The pool — 154 recipes already indexed
and tagged. Use it when the user has no saved recipes yet, or to **top up a lane that's too thin
to fill a week without repeating**. It reflects one household's taste, so build the user's own
index from their saved recipes as soon as there are any, and treat the starter as the fallback.

**Read the lane counts before planning.** The pool's shape is a constraint you can't see from
inside one week. If one protein is a third of the index, weeks will drift toward it unless you
push back; if a lane has only two or three entries, it **cannot** sustain a weekly slot without
repeating — either accept the repeat or don't put it in the rotation. Say which is happening.

Apply the rulebook's standing filters *before* shortlisting: allergy flags, which proteins are
restricted to evenings or weekends, anything currently paused, and what the last 2–3 plans used.
**The index doesn't know what was cooked recently** — that's still the week plans' job.

## Scraping Real Nutrition

`recipe-scrape.py` in this skill's directory. Never estimate macros.

```bash
python3 <skill-dir>/recipe-scrape.py search "chicken greens"
python3 <skill-dir>/recipe-scrape.py nutrition <url> [<url>…]   # sorted by kcal/g protein
python3 <skill-dir>/recipe-scrape.py recipe <url>               # ingredients + steps
```

No login needed — the recipe JSON-LD is in the public HTML. Two gotchas are already handled in
the script; don't re-derive them:
- The tag is `<script type="application/ld+json" data-next-head="">` — a regex ending in `">`
  matches **zero** recipes.
- Without `curl --compressed`, gzip bytes raise `'utf-8' codec can't decode byte 0x8b`.

**`kcal per gram of protein` is the metric that sorts dishes on a cut.** Under ~15 good, over ~25
a red flag. Put it in every plan.

## Quick Reference — the traps

| Trap | Rule |
|---|---|
| Beef at a weekday lunch | **Never.** Nanny doesn't eat beef. Evening/weekend only — Friday PM is the safe slot so leftovers sit across the weekend |
| Dairy or egg anywhere | Partner is allergic. Watch butter finishes, paneer, yogurt garnish, egg noodles, packaged sauces |
| Banana | Not in the house. **Mango** is the substitute in smoothies |
| Shrimp | Paused since 2026-04-19 until the flag lifts |
| Meatballs | Partner dislikes — never in a shared plan |
| Chile in the base | Can't be removed from the toddler's portion later. Base chile-free, heat at the table |
| Whole spices | Cardamom pods, cloves, cinnamon sticks — fish out and **count them** before serving |
| Same green two days running | Rotate. Escalate the form only after acceptance |
| Estimating macros | Scrape the JSON-LD instead |
| Cold salads | Warm mains preferred, even in summer |
| Buying cooked weight | Proteins lose ~25% cooking — buy the **raw** weight |
| Diapers/wipes on a list | Anything auto-shipped is never added — that's how you get a double order |
| Checking out an online cart | **Never.** Add to cart, then stop. The user places the order |

## Common Mistakes

- **Planning the meal but not the shop.** The list must be organized protein → produce → pantry →
  check-if-you-have → weekly recurring, or the trip takes twice as long.
- **Per-serving macros without the daily rollup.** Lunch and dinner are usually *the same dish
  reheated* — that doubles it. A 731 kcal dish becomes a 1,462 kcal day.
- **Silently dropping a constraint** because it made the plan awkward. Say so instead.
- **Forgetting the defrost.** Anything frozen needs a reminder the night before, on the calendar.
- **Writing to the shopping app or calendar unasked.** Build the list, show it, then offer.
- **`git push`.** A launchd timer owns the remote. Commit locally and stop.

## Real-World Impact

The Aug 3 2026 week shipped a dish at **29.2 kcal per gram of protein** — 1,462 kcal for 50 g of
protein across the day, mathematically impossible to hit the target around. It was invisible until
the numbers were scraped and put in a table. The Aug 17 plan, built with the same recipes-first
process but with `kcal/g protein` as a sorting column, had a **worst dish of 15.7**.
