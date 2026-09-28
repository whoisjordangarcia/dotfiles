# Starter Rotation Pool — 154 NYT recipes

A ready-made pool to plan from, so a fresh setup isn't searching from scratch for its first
several weeks. **Metadata only** — title, link, macros, tags. Full ingredients and steps live at
NYT and get pulled on demand for the handful actually being cooked:

```bash
python3 <skill-dir>/recipe-scrape.py recipe <url>
```

> [!note] This is a seed, not the user's pool
> These came from one household's saved recipes, so the lane counts reflect *their* taste, not
> anyone else's. On first run, **build the user's own index** from recipes they've already saved
> (see the rotation index section in SKILL.md) and treat this file as a fallback or a top-up when
> a protein lane is too thin to fill a week without repeating.

## How to read it

| Column | Meaning |
|---|---|
| **kcal/gP** | Calories per gram of protein — the column that sorts dishes on a cut. **Bold** = under 15. Over ~25 is a red flag |
| **Protein** | Detected from the ingredient list. Drives the rotation — don't repeat back-to-back |
| **Greens** | Which leafy vegetables it carries. Empty means a green has to be bolted on |
| **⚠️** | `dairy` / `egg` detected in the ingredients. **Verify before trusting** — it's a regex and it flags garnishes and optional items too. Coconut/oat/nut milks are already excluded |

**Filter against the rulebook before shortlisting**: allergies, which proteins are restricted to
evenings or weekends, anything paused, and what the last 2–3 plans already used. This file has no
idea what was cooked recently.

## Lane depth

| Protein | Count | |
|---|---|---|
| [chicken](#chicken) | 56 | ⚠️ over-represented — weeks drift here unless pushed back |
| [turkey](#turkey) | 3 | ⚠️ too thin to fill a weekly slot without repeating |
| [salmon](#salmon) | 17 |  |
| [fish](#fish) | 11 |  |
| [shrimp](#shrimp) | 2 | ⚠️ too thin to fill a weekly slot without repeating |
| [tofu](#tofu) | 21 |  |
| [legume](#legume) | 9 |  |
| [vegetarian](#vegetarian) | 12 |  |
| [egg](#egg) | 3 | ⚠️ too thin to fill a weekly slot without repeating |
| [pork](#pork) | 1 | ⚠️ too thin to fill a weekly slot without repeating |
| [beef](#beef) | 18 |  |
| [lamb](#lamb) | 1 | ⚠️ too thin to fill a weekly slot without repeating |

**63 of 154** are under 15 kcal/g protein. **60** carry a dairy or egg flag.


## chicken

| Recipe | kcal/gP | kcal | Prot | Time | Rating | Greens | ⚠️ |
|---|---|---|---|---|---|---|---|
| [Chicken in Mustard Sauce](https://cooking.nytimes.com/recipes/4424-chicken-in-mustard-sauce) | **6.3** | 204 | 32g | 35 min | 4★/3243 | - | — |
| [Quick Harissa Apricot Chicken](https://cooking.nytimes.com/recipes/778010695-quick-harissa-apricot-chicken) | **6.9** | 368 | 53g | 20 min | 5★/565 | - | — |
| [Blackened Chicken Breasts](https://cooking.nytimes.com/recipes/1025408-blackened-chicken-breasts) | **7.0** | 318 | 45g | 20 min | 5★/2410 | - | — |
| [Slow Cooker Hoisin Garlic Chicken](https://cooking.nytimes.com/recipes/1027037-slow-cooker-hoisin-garlic-chicken) | **7.1** | 408 | 58g | 120 min | 5★/4905 | - | — |
| [Chicken and Herb Salad With Nuoc Cham](https://cooking.nytimes.com/recipes/1022445-chicken-and-herb-salad-with-nuoc-cham) | **7.2** | 288 | 40g | 35 min | 5★/3082 | arugula, cabbage, watercress | — |
| [Slow Cooker Salsa Verde Chicken](https://cooking.nytimes.com/recipes/1020669-slow-cooker-salsa-verde-chicken) | **7.5** | 268 | 36g | 300 min | 4★/8037 | - | — |
| [Pressure Cooker Salsa Verde Chicken](https://cooking.nytimes.com/recipes/1020670-pressure-cooker-salsa-verde-chicken) | **7.5** | 268 | 36g | 35 min | 5★/3348 | - | — |
| [Slow Cooker Gochujang Chicken and Tomatoes](https://cooking.nytimes.com/recipes/1026943-slow-cooker-gochujang-chicken-and-tomatoes) | **8.0** | 341 | 42g | 360 min | 5★/1254 | - | — |
| [Dijon Chicken With Tomatoes and Scallions](https://cooking.nytimes.com/recipes/1027150-dijon-chicken-with-tomatoes-and-scallions) | **9.4** | 336 | 36g | 40 min | 5★/3502 | - | — |
| [Balsamic Roasted Chicken With Peaches](https://cooking.nytimes.com/recipes/1027274-balsamic-roasted-chicken-with-peaches) | **9.5** | 396 | 42g | 45 min | 5★/488 | - | — |
| [Turmeric-Black Pepper Chicken With Asparagus](https://cooking.nytimes.com/recipes/1020970-turmeric-black-pepper-chicken-with-asparagus) | **10.3** | 257 | 25g | 15 min | 5★/27541 | asparagus | — |
| [Instant Pot Chicken Juk With Scallion Sauce](https://cooking.nytimes.com/recipes/1021778-instant-pot-chicken-juk-with-scallion-sauce) | **10.3** | 456 | 44g | 20 min | 5★/1965 | spinach | — |
| [Seared Orange Chicken and Broccoli](https://cooking.nytimes.com/recipes/765910967-seared-orange-chicken-and-broccoli) | **10.6** | 565 | 53g | 35 min | 4★/730 | broccoli | — |
| [One-Pot Chicken With Greens and Beans](https://cooking.nytimes.com/recipes/757967089-one-pan-chicken-with-greens-and-beans) | **11.1** | 576 | 52g | 35 min | 5★/315 | chard | — |
| [Pressure Cooker Chipotle-Honey Chicken Tacos](https://cooking.nytimes.com/recipes/1020043-pressure-cooker-chipotle-honey-chicken-tacos) | **11.2** | 476 | 42g | 35 min | 5★/6771 | - | — |
| [Easy Chicken Tacos](https://cooking.nytimes.com/recipes/1026853-easy-chicken-tacos) | **11.4** | 217 | 19g | 30 min | 5★/3330 | - | — |
| [Roasted Chicken Thighs With Cauliflower and Herby Yogurt](https://cooking.nytimes.com/recipes/1021945-roasted-chicken-thighs-with-cauliflower-and-herby-yogurt) | **11.5** | 514 | 45g | 60 min | 5★/6770 | - | dairy |
| [Slow-Cooker Chicken Stew With Spinach, Lemon and Feta](https://cooking.nytimes.com/recipes/1023737-slow-cooker-chicken-stew-with-spinach-lemon-and-feta) | **11.5** | 344 | 30g | 255 min | 4★/1371 | spinach | dairy |
| [Chicken and Kale Hatch Chile Bowl](https://cooking.nytimes.com/recipes/777654017-chicken-and-kale-hatch-chile-bowl) | **11.5** | 571 | 50g | 20 min | 4★/214 | kale | — |
| [Chicken and White Bean Stew](https://cooking.nytimes.com/recipes/767821616-chicken-and-white-bean-stew) | **11.9** | 575 | 48g | 45 min | 5★/3198 | escarole, kale | dairy |
| [Ginger Chicken and Rice Soup With Zucchini](https://cooking.nytimes.com/recipes/1026507-ginger-chicken-and-rice-soup-with-zucchini) | **12.3** | 157 | 13g | 50 min | 5★/4608 | - | — |
| [Tomato Basil Chicken Breasts](https://cooking.nytimes.com/recipes/1027093-tomato-basil-chicken-breasts) | **12.3** | 515 | 42g | 30 min | 5★/4388 | - | dairy |
| [Parmesan-Crusted Chicken](https://cooking.nytimes.com/recipes/1025525-parmesan-crusted-chicken) | **12.6** | 473 | 37g | 45 min | 5★/4347 | - | dairy egg |
| [Chicken and Red Lentil Soup With Lemony Yogurt](https://cooking.nytimes.com/recipes/1026473-chicken-and-red-lentil-soup-with-lemony-yogurt) | **12.6** | 603 | 48g | 60 min | 5★/5633 | - | dairy |
| [Chipotle Chicken Salad](https://cooking.nytimes.com/recipes/777656482-chipotle-chicken-salad) | **12.6** | 520 | 41g | 20 min | 5★/89 | - | egg |
| [Skillet Chicken With Mushrooms and Caramelized Onions](https://cooking.nytimes.com/recipes/1022068-skillet-chicken-with-mushrooms-and-caramelized-onions) | **13.2** | 599 | 45g | 30 min | 5★/16598 | - | dairy |
| [Sheet-Pan Chicken and Tomatoes With Balsamic Tahini](https://cooking.nytimes.com/recipes/1025358-sheet-pan-chicken-and-tomatoes-with-balsamic-tahini) | **13.3** | 539 | 41g | 20 min | 5★/755 | green bean | — |
| [Weeknight Chicken Tagine](https://cooking.nytimes.com/recipes/1025549-weeknight-chicken-tagine) | **13.6** | 388 | 28g | 40 min | 5★/2843 | - | — |
| [Keema Palak (Ground Chicken and Spinach Curry)](https://cooking.nytimes.com/recipes/1026917-keema-palak-ground-chicken-and-spinach-curry) | **14.6** | 364 | 25g | 40 min | 5★/1361 | spinach | dairy |
| [Chicken and Mushroom Soup With Spinach](https://cooking.nytimes.com/recipes/770231994-chicken-and-mushroom-soup-with-spinach) | **14.7** | 458 | 31g | 25 min | 5★/680 | spinach | — |
| [One-Pot Chicken Meatballs With Greens](https://cooking.nytimes.com/recipes/1025342-one-pot-chicken-meatballs-with-greens) | **14.9** | 356 | 24g | 40 min | 5★/5375 | chard | dairy |
| [Skillet Hot Honey Chicken With Hearty Greens](https://cooking.nytimes.com/recipes/1019790-skillet-hot-honey-chicken-with-hearty-greens) | 15.0 | 608 | 40g | 30 min | 4★/2422 | escarole, kale, mustard greens | — |
| [Chicken Salad Slaw With Peanuts and Nori](https://cooking.nytimes.com/recipes/778605548-chicken-salad-slaw-with-peanuts-and-nori) | 15.0 | 458 | 30g | 30 min | 5★/683 | cabbage | dairy |
| [Pancit](https://cooking.nytimes.com/recipes/1024747-pancit) | 15.5 | 354 | 23g | 45 min | 4★/973 | cabbage | — |
| [Sheet-Pan Herby Roast Chicken With Peas and Carrots](https://cooking.nytimes.com/recipes/1025292-sheet-pan-herby-roast-chicken-with-peas-and-carrots) | 16.3 | 442 | 27g | 45 min | 4★/477 | - | dairy |
| [Braised Chicken Thighs With Greens and Olives](https://cooking.nytimes.com/recipes/1019405-braised-chicken-thighs-with-greens-and-olives) | 16.4 | 519 | 32g | 40 min | 4★/1090 | chard, escarole, kale | — |
| [Spiced Chicken With Sweet Potatoes](https://cooking.nytimes.com/recipes/1025055-spiced-chicken-with-sweet-potatoes) | 16.5 | 916 | 56g | 75 min | 5★/885 | - | — |
| [Roasted Chicken With Fennel and Peaches](https://cooking.nytimes.com/recipes/781114202-roasted-chicken-with-fennel-and-peaches) | 16.7 | 564 | 34g | 60 min | 5★/579 | - | — |
| [One-Pan Kuku Paka (Chicken in Coconut Curry)](https://cooking.nytimes.com/recipes/781040991-one-pan-kuku-paka-chicken-in-coconut-curry) | 16.8 | 517 | 31g | 40 min | 5★/158 | - | dairy |
| [Paprika Chicken and Potatoes](https://cooking.nytimes.com/recipes/1025628-paprika-chicken-and-potatoes) | 17.0 | 641 | 38g | 35 min | 5★/10753 | - | egg |
| [Thai-Style Coconut Curry Chicken Tacos](https://cooking.nytimes.com/recipes/1019815-thai-style-coconut-curry-chicken-tacos) | 17.3 | 490 | 28g | 25 min | 5★/1676 | - | — |
| [Sheet-Pan Chicken With Black Beans and Squash](https://cooking.nytimes.com/recipes/771531010-sheet-pan-chicken-with-black-beans-and-squash) | 17.5 | 635 | 36g | 45 min | 5★/1122 | - | dairy |
| [Scallion Chicken and Rice for Two](https://cooking.nytimes.com/recipes/777998043-scallion-chicken-and-rice-for-two) | 17.9 | 804 | 45g | 45 min | 5★/390 | - | — |
| [Sheet-Pan Malai Chicken and Potatoes](https://cooking.nytimes.com/recipes/1026512-sheet-pan-malai-chicken-and-potatoes) | 18.3 | 675 | 37g | 45 min | 5★/2083 | - | dairy |
| [Sheet-Pan Roast Chicken and Mustard-Glazed Cabbage](https://cooking.nytimes.com/recipes/1020659-sheet-pan-roast-chicken-and-mustard-glazed-cabbage) | 18.7 | 667 | 36g | 45 min | 5★/3731 | arugula, cabbage | — |
| [Pollo a la Piña (Pineapple Chicken)](https://cooking.nytimes.com/recipes/1026321-pollo-a-la-pina-pineapple-chicken) | 19.3 | 582 | 30g | 55 min | 5★/1604 | - | — |
| [One-Pot Chicken and Rice With Caramelized Lemon](https://cooking.nytimes.com/recipes/1025436-one-pot-chicken-and-rice-with-caramelized-lemon) | 19.8 | 831 | 42g | 55 min | 5★/13608 | - | — |
| [Honey Mustard Chicken Pasta](https://cooking.nytimes.com/recipes/778602430-honey-mustard-chicken-pasta) | 22.6 | 661 | 29g | 30 min | 4★/154 | - | dairy |
| [Chickpea Stew With Orzo and Mustard Greens](https://cooking.nytimes.com/recipes/1015767-chickpea-stew-with-orzo-and-mustard-greens) | 22.8 | 244 | 11g | 25 min | 5★/7989 | mustard greens, spinach | — |
| [One-Pan Orzo With Spinach and Feta](https://cooking.nytimes.com/recipes/1021485-one-pan-orzo-with-spinach-and-feta) | 23.7 | 277 | 12g | 30 min | 5★/22592 | spinach | dairy |
| [Baked Coconut Red Lentils and Greens](https://cooking.nytimes.com/recipes/773673535-baked-coconut-red-lentils-and-greens) | 24.4 | 409 | 17g | 50 min | 5★/463 | spinach | — |
| [One-Pot Tortellini with Prosciutto and Peas](https://cooking.nytimes.com/recipes/1025271-one-pot-tortellini-with-prosciutto-and-peas) | 26.2 | 753 | 29g | 25 min | 5★/9101 | - | dairy |
| [Sheet-Pan Turmeric Chicken and Crispy Rice](https://cooking.nytimes.com/recipes/1025011-sheet-pan-turmeric-chicken-and-crispy-rice) | 26.5 | 1611 | 61g | 100 min | 5★/3395 | - | — |
| [Spiced Chickpea Stew With Coconut and Turmeric](https://cooking.nytimes.com/recipes/1019772-spiced-chickpea-stew-with-coconut-and-turmeric) | 34.3 | 678 | 20g | 55 min | 5★/30747 | chard, collard, kale | dairy |
| [Mushroom Potpie](https://cooking.nytimes.com/recipes/1020731-mushroom-potpie) | 59.5 | 785 | 13g | 90 min | 4★/2833 | kale | dairy egg |
| [Suya Spiced Grilled Chicken Thighs With Nectarines](https://cooking.nytimes.com/recipes/1027038-suya-spiced-grilled-chicken-thighs-with-nectarines) | - | - | - | 50 min | 5★/262 | - | — |

## turkey

| Recipe | kcal/gP | kcal | Prot | Time | Rating | Greens | ⚠️ |
|---|---|---|---|---|---|---|---|
| [Ground Turkey, Shiitake and Cashew Lettuce Cups](https://cooking.nytimes.com/recipes/1025543-ground-turkey-shiitake-and-cashew-lettuce-cups) | **12.3** | 303 | 25g | 20 min | 5★/1788 | lettuce | dairy |
| [Turkey-Ricotta Meatballs](https://cooking.nytimes.com/recipes/1023664-turkey-ricotta-meatballs) | **13.3** | 392 | 29g | 25 min | 5★/2300 | - | dairy |
| [Lemony White Bean Soup With Turkey and Greens](https://cooking.nytimes.com/recipes/1021776-lemony-white-bean-soup-with-turkey-and-greens) | 15.7 | 559 | 36g | 45 min | 5★/22198 | broccoli rabe, collard, kale | — |

## salmon

| Recipe | kcal/gP | kcal | Prot | Time | Rating | Greens | ⚠️ |
|---|---|---|---|---|---|---|---|
| [Coconut Fish and Tomato Bake](https://cooking.nytimes.com/recipes/1022129-coconut-fish-and-tomato-bake) | **10.8** | 406 | 38g | 20 min | 5★/12473 | - | — |
| [Salmon Teriyaki](https://cooking.nytimes.com/recipes/1024206-salmon-teriyaki) | **11.5** | 340 | 30g | 20 min | 4★/592 | - | — |
| [Blackened Salmon](https://cooking.nytimes.com/recipes/1026060-blackened-salmon) | **11.6** | 481 | 41g | 20 min | 5★/612 | - | dairy |
| [Mustardy Sheet-Pan Salmon With Greens](https://cooking.nytimes.com/recipes/1027227-mustardy-sheet-pan-salmon-with-greens) | **13.5** | 429 | 32g | 25 min | 5★/1324 | chard, spinach | — |
| [Salpicón de Pescado (Spicy Citrus-Marinated Fish)](https://cooking.nytimes.com/recipes/1026323-salpicon-de-pescado-spicy-citrus-marinated-fish) | **14.0** | 542 | 39g | 40 min | 5★/740 | - | — |
| [Oven-Seared Salmon With Corn and Tomatoes](https://cooking.nytimes.com/recipes/1025361-oven-seared-salmon-with-corn-and-tomatoes) | **14.9** | 697 | 47g | 25 min | 5★/3359 | - | egg |
| [Sheet-Pan Salmon and Broccoli With Sesame and Ginger](https://cooking.nytimes.com/recipes/1020765-sheet-pan-salmon-and-broccoli-with-sesame-and-ginger) | 15.0 | 603 | 40g | 20 min | 5★/6926 | broccoli | — |
| [Sheet-Pan Citrus Salmon With White Beans](https://cooking.nytimes.com/recipes/767819809-sheet-pan-citrus-salmon-with-white-beans) | 15.0 | 562 | 37g | 30 min | 4★/241 | - | — |
| [Coconut-Chile Salmon and Greens](https://cooking.nytimes.com/recipes/769629632-coconut-chile-salmon-and-greens) | 16.1 | 515 | 32g | 30 min | 5★/116 | chard | — |
| [Coconut-Dill Salmon With Green Beans and Corn](https://cooking.nytimes.com/recipes/1024460-coconut-dill-salmon-with-green-beans-and-corn) | 16.2 | 421 | 26g | 40 min | 5★/2266 | green bean | — |
| [Likama Roasted Salmon With Cabbage Salad](https://cooking.nytimes.com/recipes/1025548-likama-roasted-salmon-with-cabbage-salad) | 16.2 | 409 | 25g | 25 min | 5★/595 | cabbage | — |
| [Charred Broccoli and Salmon Noodle Salad](https://cooking.nytimes.com/recipes/776802219-charred-broccoli-and-salmon-noodle-salad) | 17.3 | 585 | 34g | 25 min | 5★/522 | broccoli | — |
| [Salmon and Cherry Tomato Curry](https://cooking.nytimes.com/recipes/765904408-salmon-and-cherry-tomato-curry) | 17.7 | 719 | 41g | 30 min | 5★/2542 | spinach | dairy |
| [Slow-Roasted Salmon With Salsa Verde](https://cooking.nytimes.com/recipes/1025331-slow-roasted-salmon-with-salsa-verde) | 17.8 | 653 | 37g | 35 min | 5★/662 | - | — |
| [Sticky Miso Salmon Bowl](https://cooking.nytimes.com/recipes/1025510-sticky-miso-salmon-bowl) | 18.1 | 888 | 49g | 35 min | 5★/15149 | - | dairy |
| [Sesame Salmon Bowls](https://cooking.nytimes.com/recipes/1022255-sesame-salmon-bowls) | 20.0 | 784 | 39g | 40 min | 5★/10009 | - | — |
| [One-Pot Miso-Turmeric Salmon and Coconut Rice](https://cooking.nytimes.com/recipes/1026734-one-pot-miso-turmeric-salmon-and-coconut-rice) | 20.8 | 976 | 47g | 40 min | 5★/3903 | spinach | — |

## fish

| Recipe | kcal/gP | kcal | Prot | Time | Rating | Greens | ⚠️ |
|---|---|---|---|---|---|---|---|
| [One-Pan Roasted Fish With Cherry Tomatoes](https://cooking.nytimes.com/recipes/1020454-one-pan-roasted-fish-with-cherry-tomatoes) | **7.8** | 261 | 34g | 30 min | 5★/12917 | - | — |
| [Parchment-Steamed Fish With Buttered Radishes](https://cooking.nytimes.com/recipes/777045284-parchment-steamed-fish-with-buttered-radishes) | **8.0** | 612 | 77g | 40 min | 5★/163 | - | dairy |
| [Baked Cod](https://cooking.nytimes.com/recipes/1026480-baked-cod) | **8.3** | 214 | 26g | 30 min | 5★/1425 | - | — |
| [Puttanesca Poached Fish](https://cooking.nytimes.com/recipes/769726376-puttanesca-poached-fish) | **9.5** | 337 | 36g | 35 min | 5★/818 | - | — |
| [Glazed Cod With Bok Choy, Ginger and Oyster Sauce](https://cooking.nytimes.com/recipes/1020306-glazed-cod-with-bok-choy-ginger-and-oyster-sauce) | **10.6** | 362 | 34g | 20 min | 4★/2031 | bok choy | dairy egg |
| [Cod With Brown Butter and Pine Nuts](https://cooking.nytimes.com/recipes/1026453-cod-with-brown-butter-and-pine-nuts) | **10.6** | 456 | 43g | 15 min | 5★/834 | - | dairy |
| [Roasted Cod and Potatoes](https://cooking.nytimes.com/recipes/8135-roasted-cod-and-potatoes) | **12.9** | 452 | 35g | 60 min | 4★/4228 | - | dairy |
| [Baked Fish With Olives and Ginger](https://cooking.nytimes.com/recipes/1025052-baked-fish-with-olives-and-ginger) | **13.1** | 457 | 35g | 30 min | 5★/3402 | - | — |
| [Coconut-Poached Fish With Bok Choy](https://cooking.nytimes.com/recipes/1019384-coconut-poached-fish-with-bok-choy) | 16.1 | 636 | 40g | 25 min | 5★/2821 | bok choy | — |
| [One-Pot Roman Chicken Cacciatore With Potatoes](https://cooking.nytimes.com/recipes/1026287-one-pot-roman-chicken-cacciatore-with-potatoes) | 17.1 | 683 | 40g | 60 min | 5★/4406 | - | — |
| [Scallion-Oil Fish](https://cooking.nytimes.com/recipes/1026167-scallion-oil-fish) | 22.8 | 1023 | 45g | 25 min | 5★/2426 | - | — |

## shrimp

| Recipe | kcal/gP | kcal | Prot | Time | Rating | Greens | ⚠️ |
|---|---|---|---|---|---|---|---|
| [Stir-Fried Sesame Shrimp and Spinach](https://cooking.nytimes.com/recipes/12382-stir-fried-sesame-shrimp-and-spinach) | **8.7** | 235 | 27g | 15 min | 5★/2437 | spinach | — |
| [Ginger-Garlic Shrimp With Coconut Milk](https://cooking.nytimes.com/recipes/1023206-ginger-garlic-shrimp-with-coconut-milk) | 17.2 | 469 | 27g | 20 min | 5★/10256 | spinach | — |

## tofu

| Recipe | kcal/gP | kcal | Prot | Time | Rating | Greens | ⚠️ |
|---|---|---|---|---|---|---|---|
| [Chilled Tofu With Gochujang Sauce](https://cooking.nytimes.com/recipes/1025664-chilled-tofu-with-gochujang-sauce) | **10.1** | 218 | 22g | 10 min | 5★/931 | - | — |
| [Ponzu Tofu and Mushroom Rice Bowls](https://cooking.nytimes.com/recipes/1024252-ponzu-tofu-and-mushroom-rice-bowls) | **11.9** | 331 | 28g | 30 min | 5★/546 | kale, snow pea, spinach | — |
| [Tofu Laab](https://cooking.nytimes.com/recipes/1022299-tofu-laab) | **12.9** | 278 | 22g | 20 min | 4★/1739 | lettuce | dairy |
| [Shredded Tofu and Shiitake Stir-Fry](https://cooking.nytimes.com/recipes/1017765-shredded-tofu-and-shiitake-stir-fry) | **13.1** | 307 | 23g | 20 min | 4★/2363 | - | — |
| [Chile Tofu](https://cooking.nytimes.com/recipes/779397405-chile-tofu) | **13.9** | 335 | 24g | 35 min | 5★/1063 | broccoli | — |
| [Seared Tofu With Kimchi](https://cooking.nytimes.com/recipes/1025987-seared-tofu-with-kimchi) | **14.5** | 286 | 20g | 25 min | 5★/725 | cabbage | — |
| [Roasted Brussels Sprouts and Tofu With Chile Lime Dressing](https://cooking.nytimes.com/recipes/1026312-roasted-brussels-sprouts-and-tofu-with-chile-lime-dressing) | 17.0 | 425 | 25g | 50 min | 5★/1556 | - | — |
| [Ginger-Scallion Tofu and Greens](https://cooking.nytimes.com/recipes/1025700-ginger-scallion-tofu-and-greens) | 17.2 | 384 | 22g | 20 min | 4★/413 | bok choy | — |
| [Crispy Tofu Nuggets](https://cooking.nytimes.com/recipes/767029318-crispy-tofu-nuggets) | 17.4 | 182 | 10g | 45 min | 5★/629 | - | — |
| [Sweet Chile Grain Bowl With Tofu](https://cooking.nytimes.com/recipes/1024956-sweet-chile-grain-bowl-with-tofu) | 18.8 | 284 | 15g | 50 min | 5★/2602 | cabbage | — |
| [Lemon-Miso Tofu With Broccoli](https://cooking.nytimes.com/recipes/1026706-lemon-miso-tofu-with-broccoli) | 19.9 | 352 | 18g | 45 min | 5★/4243 | broccoli | — |
| [Crispy Tofu Tacos](https://cooking.nytimes.com/recipes/1026900-crispy-tofu-tacos) | 19.9 | 384 | 19g | 75 min | 5★/3521 | - | egg |
| [Lemongrass Tofu and Broccoli](https://cooking.nytimes.com/recipes/1025400-lemongrass-tofu-and-broccoli) | 20.4 | 322 | 16g | 25 min | 5★/2425 | broccoli | — |
| [Masala Chickpeas With Tofu and Blistered Tomatoes](https://cooking.nytimes.com/recipes/1026964-masala-chickpeas-with-tofu-and-blistered-tomatoes) | 20.7 | 376 | 18g | 35 min | 5★/2306 | - | dairy |
| [Lemon-Pepper Tofu and Snap Peas](https://cooking.nytimes.com/recipes/1025963-lemon-pepper-tofu-and-snap-peas) | 21.3 | 664 | 31g | 30 min | 5★/2182 | - | — |
| [Crispy Tofu With Cashews and Blistered Snap Peas](https://cooking.nytimes.com/recipes/1021200-crispy-tofu-with-cashews-and-blistered-snap-peas) | 24.0 | 422 | 18g | 30 min | 4★/10401 | - | — |
| [I Can’t Believe It’s Not Chicken (Super-Savory Grated Tofu)](https://cooking.nytimes.com/recipes/1027269-i-cant-believe-its-not-chicken-super-savory-grated-tofu) | 28.7 | 396 | 14g | 30 min | 5★/4342 | - | — |
| [Sesame-Soy Tofu Bowls](https://cooking.nytimes.com/recipes/767628149-sesame-soy-tofu-bowls) | 28.7 | 894 | 31g | 30 min | 5★/221 | - | — |
| [Coconut Saag](https://cooking.nytimes.com/recipes/1024665-coconut-saag) | 29.1 | 732 | 25g | 35 min | 4★/3552 | mustard greens, spinach | dairy |
| [Tofu Schnitzel With Buttermilk Slaw](https://cooking.nytimes.com/recipes/776710293-tofu-schnitzel-with-buttermilk-slaw) | 50.2 | 924 | 18g | 35 min | 5★/247 | cabbage | dairy egg |
| [Crispy Tofu Shawarma](https://cooking.nytimes.com/recipes/759520233-crispy-tofu-shawarma) | - | - | - | 50 min | 5★/892 | - | — |

## legume

| Recipe | kcal/gP | kcal | Prot | Time | Rating | Greens | ⚠️ |
|---|---|---|---|---|---|---|---|
| [Slow Cooker Spicy Coconut Lentil Soup](https://cooking.nytimes.com/recipes/769017392-slow-cooker-coconut-lentil-soup) | 20.9 | 476 | 23g | 310 min | 5★/415 | collard, kale, spinach | — |
| [Sri Lankan Dal With Coconut and Lime Kale](https://cooking.nytimes.com/recipes/1018939-sri-lankan-dal-with-coconut-and-lime-kale) | 22.2 | 503 | 23g | 55 min | 4★/2046 | kale | dairy |
| [Loaded Sweet Potatoes With Black Beans and Cheddar](https://cooking.nytimes.com/recipes/1019600-loaded-sweet-potatoes-with-black-beans-and-cheddar) | 25.7 | 196 | 8g | 50 min | 5★/7030 | - | — |
| [Slow Cooker Chickpea Stew With Lemon and Coconut](https://cooking.nytimes.com/recipes/1026953-slow-cooker-chickpea-stew-with-lemon-and-coconut) | 27.6 | 600 | 22g | 480 min | 4★/907 | - | — |
| [Roasted Honey Nut Squash and Chickpeas With Hot Honey](https://cooking.nytimes.com/recipes/1023687-roasted-honey-nut-squash-and-chickpeas-with-hot-honey) | 29.9 | 550 | 18g | 60 min | 5★/8677 | - | dairy |
| [Beans Marbella](https://cooking.nytimes.com/recipes/1023274-beans-marbella) | 31.7 | 650 | 20g | 150 min | 4★/1397 | - | dairy |
| [Taverna Salad](https://cooking.nytimes.com/recipes/1025202-taverna-salad) | 32.6 | 410 | 13g | 45 min | 5★/10548 | - | dairy |
| [Orzo Salad](https://cooking.nytimes.com/recipes/1025349-orzo-salad) | 33.1 | 368 | 11g | 60 min | 5★/4723 | - | dairy |
| [Red Curry Lentils With Sweet Potatoes and Spinach](https://cooking.nytimes.com/recipes/1020766-red-curry-lentils-with-sweet-potatoes-and-spinach) | 38.6 | 467 | 12g | 60 min | 5★/19730 | spinach | — |

## vegetarian

| Recipe | kcal/gP | kcal | Prot | Time | Rating | Greens | ⚠️ |
|---|---|---|---|---|---|---|---|
| [Easy Air-Fryer Asparagus](https://cooking.nytimes.com/recipes/1025542-easy-air-fryer-asparagus) | **12.6** | 53 | 4g | 10 min | 5★/211 | asparagus | dairy |
| [Stewed Greens With Tomatoes and Mint](https://cooking.nytimes.com/recipes/1013847-stewed-greens-with-tomatoes-and-mint) | 23.7 | 123 | 5g | 60 min | 5★/68 | chard, kale | — |
| [Cold Noodle Salad With Spicy Peanut Sauce](https://cooking.nytimes.com/recipes/1022329-cold-noodle-salad-with-spicy-peanut-sauce) | 27.1 | 638 | 24g | 20 min | 5★/9793 | - | — |
| [Spiced Pea Stew With Yogurt](https://cooking.nytimes.com/recipes/1026665-spiced-pea-stew-with-yogurt) | 28.7 | 494 | 17g | 70 min | 5★/998 | - | dairy |
| [Summer Vegetable Pancit Canton](https://cooking.nytimes.com/recipes/782479200-summer-vegetable-pancit-canton) | 30.0 | 438 | 15g | 30 min | 5★/183 | green bean | — |
| [Blistered Broccoli Pasta With Walnuts, Pecorino and Mint](https://cooking.nytimes.com/recipes/1020997-blistered-broccoli-pasta-with-walnuts-pecorino-and-mint) | 32.8 | 787 | 24g | 15 min | 5★/5522 | broccoli | dairy |
| [Coconut-Braised Collard Greens](https://cooking.nytimes.com/recipes/1020087-coconut-braised-collard-greens) | 34.5 | 300 | 9g | 20 min | 5★/2094 | collard | dairy |
| [Crispy Gnocchi With Spinach and Feta](https://cooking.nytimes.com/recipes/1025701-crispy-gnocchi-with-spinach-and-feta) | 36.2 | 442 | 12g | 25 min | 5★/6929 | spinach | dairy |
| [Lemon-Garlic Kale Salad](https://cooking.nytimes.com/recipes/1015707-lemon-garlic-kale-salad) | 38.4 | 495 | 13g | 25 min | 5★/11103 | kale | dairy |
| [Eleven Madison Park Granola](https://cooking.nytimes.com/recipes/1014304-eleven-madison-park-granola) | 47.3 | 355 | 8g | 40 min | 5★/11361 | - | — |
| [One-Pot Turmeric Coconut Rice With Greens](https://cooking.nytimes.com/recipes/1019920-one-pot-turmeric-coconut-rice-with-greens) | 67.5 | 371 | 6g | 40 min | 4★/8528 | chard, kale, spinach | — |
| [Ginger-Lime Cucumber Salad](https://cooking.nytimes.com/recipes/1026798-ginger-lime-cucumber-salad) | 79.1 | 71 | 1g | 25 min | 5★/847 | - | — |

## egg

| Recipe | kcal/gP | kcal | Prot | Time | Rating | Greens | ⚠️ |
|---|---|---|---|---|---|---|---|
| [Mortadella Carbonara](https://cooking.nytimes.com/recipes/1025165-mortadella-carbonara) | 19.8 | 488 | 25g | 30 min | 4★/534 | - | dairy egg |
| [Perfect Buttermilk Pancakes](https://cooking.nytimes.com/recipes/1018180-perfect-buttermilk-pancakes) | 28.6 | 490 | 17g | 10 min | 5★/16782 | - | dairy egg |
| [One-Pot Beans, Greens and Grains](https://cooking.nytimes.com/recipes/1026472-one-pot-beans-greens-and-grains) | 28.6 | 380 | 13g | 40 min | 5★/5773 | collard, kale, spinach | dairy egg |

## pork

| Recipe | kcal/gP | kcal | Prot | Time | Rating | Greens | ⚠️ |
|---|---|---|---|---|---|---|---|
| [Crispy Gnocchi With Sausage and Broccoli](https://cooking.nytimes.com/recipes/1025733-crispy-gnocchi-with-sausage-and-broccoli) | 17.6 | 526 | 30g | 45 min | 5★/14576 | broccoli | dairy |

## beef

| Recipe | kcal/gP | kcal | Prot | Time | Rating | Greens | ⚠️ |
|---|---|---|---|---|---|---|---|
| [Barbacoa](https://cooking.nytimes.com/recipes/1024435-barbacoa) | **7.1** | 389 | 55g | 265 min | 5★/624 | - | — |
| [Pressure Cooker Guinness Beef Stew With Horseradish Cream](https://cooking.nytimes.com/recipes/1020060-pressure-cooker-guinness-beef-stew-with-horseradish-cream) | **9.0** | 952 | 106g | 90 min | 5★/1794 | - | dairy |
| [Beef Tagine With Green Beans and Olives](https://cooking.nytimes.com/recipes/1025869-beef-tagine-with-green-beans-and-olives) | **9.4** | 321 | 34g | 135 min | 5★/1008 | green bean | — |
| [Vegetable Beef Soup](https://cooking.nytimes.com/recipes/1026317-vegetable-beef-soup) | **10.2** | 334 | 33g | 140 min | 5★/514 | green bean | dairy |
| [Perfect Soy-Grilled Steak](https://cooking.nytimes.com/recipes/7841-perfect-soy-grilled-steak) | **11.5** | 345 | 30g | 30 min | 5★/1962 | - | — |
| [Mississippi Roast](https://cooking.nytimes.com/recipes/1017937-mississippi-roast) | **12.4** | 590 | 48g | 480 min | 4★/12843 | - | dairy egg |
| [Grilled Steak With Sauce Rof](https://cooking.nytimes.com/recipes/1024373-grilled-steak-with-sauce-rof) | **13.6** | 484 | 36g | 45 min | 4★/618 | - | — |
| [Ropa Vieja](https://cooking.nytimes.com/recipes/1021457-ropa-vieja) | **14.9** | 710 | 48g | 180 min | 4★/1515 | - | — |
| [Pepper Steak and Celery Stir-Fry With Lemon](https://cooking.nytimes.com/recipes/1025882-pepper-steak-and-celery-stir-fry-with-lemon) | 15.1 | 369 | 24g | 30 min | 5★/2083 | - | dairy |
| [Beef, Asparagus and Tofu Stir-Fry](https://cooking.nytimes.com/recipes/778503009-beef-asparagus-and-tofu-stir-fry) | 15.5 | 356 | 23g | 30 min | 5★/441 | asparagus | — |
| [Sheet-Pan Steak and Pepper Tacos](https://cooking.nytimes.com/recipes/771520721-sheet-pan-steak-and-pepper-tacos) | 15.8 | 382 | 24g | 45 min | 5★/338 | - | dairy |
| [Seared Tuna With Beans and Tomatoes](https://cooking.nytimes.com/recipes/780502611-seared-tuna-with-beans-and-tomatoes) | 16.5 | 442 | 27g | 110 min | 5★/65 | - | — |
| [One-Pot Cabbage Roll Soup](https://cooking.nytimes.com/recipes/1025227-one-pot-cabbage-roll-soup) | 18.2 | 438 | 24g | 35 min | 5★/2110 | cabbage | — |
| [Japanese Ground Beef Curry](https://cooking.nytimes.com/recipes/770863996-japanese-ground-beef-curry) | 21.7 | 407 | 19g | 50 min | 5★/3507 | - | — |
| [Bolognese Sauce](https://cooking.nytimes.com/recipes/1015181-marcella-hazans-bolognese-sauce) | 22.2 | 663 | 30g | 240 min | 5★/30941 | - | dairy |
| [Beef Tacos Dorados](https://cooking.nytimes.com/recipes/779812287-beef-tacos-dorados) | 24.0 | 166 | 7g | 70 min | 5★/84 | cabbage | dairy |
| [Spicy, Creamy Weeknight Bolognese](https://cooking.nytimes.com/recipes/1026551-spicy-creamy-weeknight-bolognese) | 25.4 | 639 | 25g | 35 min | 5★/6020 | - | dairy |
| [Bibimbap](https://cooking.nytimes.com/recipes/1024852-bibimbap) | - | - | - | 165 min | 4★/849 | spinach | egg |

## lamb

| Recipe | kcal/gP | kcal | Prot | Time | Rating | Greens | ⚠️ |
|---|---|---|---|---|---|---|---|
| [Rosemary Rack of Lamb With Crushed Potatoes](https://cooking.nytimes.com/recipes/1019078-rosemary-rack-of-lamb-with-crushed-potatoes) | 21.1 | 1166 | 55g | 60 min | 5★/2475 | - | — |

