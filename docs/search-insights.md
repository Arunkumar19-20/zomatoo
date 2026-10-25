# Search insights, Phase 1: logging what people search and whether the answer was good

Goal of the whole feature: tell restaurant owners which cravings are trending and not served (for example "Korean x Italian
fusion"), so they can add a dish or stock more. Phase 1 builds the data it needs. Nothing here is visible to owners yet.

## What is recorded

One row per search in `search_event`, one per tapped result in `search_click`.

| Kept | Not kept |
|---|---|
| the text typed, the cleaned-up form, the flavors and filters it was read as | account, email, phone, name |
| how many dishes were relevant and how good the best one was (see below) | IP address, device id |
| which dish ids were shown, whether the answer looked unserved | the app's anonymous client id, as is |
| a day-scoped searcher key: `HMAC(server secret, UTC date + client id or IP)`, 8 bytes | anything that links one person's searches across days |

The key changes every day, so "how many different people searched this" works per day and cannot be joined into a profile.
Searches typed in stages ("sweet", pause, "sweet but also spicy") count once: a shorter query that the same searcher extends within
20 seconds is marked `superseded`. Raw text is deleted after `search.log.retention-days` (default 90) by a nightly job.

Opt-outs: the `DNT: 1` header, `search.log.enabled=false`. Both skip the log and the search still works. A logging failure can
never fail a search.

## Is the answer good? (`UnmetClassifier`)

Result scores are relative to the best hit, so they cannot say whether anything good was found. Each search therefore records
absolute signals, and a verdict `unmet` with its basis:

- Flavor cravings ("sweet and spicy"): unserved if none of the top 3 dishes carries every flavor with an **owner-confirmed** tag and
  the first dish covers under 80% of the flavors.
- Everything else (dish names, cuisines, mixes): the words must meet in one dish. Unserved if a word is on no menu at all
  (`word-on-no-menu`), or every word is served but no single dish has them all (`no-dish-has-all-the-words`).

### What calibration showed (`docs/search-unmet-calibration.md`, real bge-small model, 126 dishes)

- **Embedding similarity cannot decide this.** bge-small gives unrelated dishes 0.5 to 0.8 whatever is asked: "birria tacos"
  (not on any menu) scored 0.79, "paneer" (on a menu) 0.74. A similarity threshold flagged answerable queries and missed
  unanswerable ones, so it is kept only to gate `relevantCount`, not to judge.
- The all-words-in-one-dish check flagged **13 of 15** made-up cravings (kimchi carbonara, korean italian fusion, moroccan tagine ...)
  and **1 of 15** answerable ones ("noodle soup": ramen is a noodle soup, but no dish says both words).
- Known false positives: mood and occasion queries made of ordinary words ("late night snack", "something to share with friends")
  are flagged `no-dish-has-all-the-words`. Missed: "birria tacos" and "poke bowl", because their words appear in some dish each.
  Phase 2 only turns cuisine and dish phrases (a lexicon plus fusion detection) into suggestions, so mood queries will not
  surface as "add this dish".
- The verdict is a per-search hint. Trends come from aggregating many searches by distinct searchers (Phase 2), which is also
  what keeps a single odd query from becoming a suggestion.

## API

| Call | Who | Notes |
|---|---|---|
| `GET /search/dishes?q=&k=&area=` | public | now returns `searchId` (null when not logged); optional header `X-Search-Client` |
| `POST /search/events/{searchId}/click` `{itemId, rank, action}` | public, rate limited | `OPEN` or `ADD_TO_CART`. Always 204. Counted only for a dish that search showed, from the same searcher, within 6 h, once per dish and action |
| `GET /admin/search/events/summary?days=&top=` | admin | searches, distinct searchers, unmet share, click rate, top queries |

Properties: `search.log.enabled`, `search.log.retention-days`, `search.log.session-secret` (set `SEARCH_LOG_SECRET` in
production; the default is for development only), `search.log.purge-cron`.

## Tests

`SearchEventLoggingTest` (12: row contents, unmet flag, DNT, logging off, no identifying fields, typing-in-stages, per-searcher
keys, click validation, retention purge with clicks, admin-only summary), `UnmetClassifierTest` (6), `UnmetCalibrationTest` (real model,
skipped without it), Flutter `dish_search_state_test.dart` (click reporting). Full backend suite: 191 passing.
Also run live against Postgres: rows written, DNT left no row, 1 click row from 4 attempts (repeat, forged client and unshown dish rejected).

---

# Phase 2: finding the trends

Turns the log into "what is rising": a nightly job reads the last five weeks of finished searches and writes a snapshot of phrases
with a status and the reason for it. Owners still see nothing; Phase 3 matches phrases to restaurants.

## From a search to a phrase (`PhraseMiner`, open vocabulary)

| Kind | When | Key | Example |
|---|---|---|---|
| FUSION | the craving touches two or more cuisines, by cuisine name or signature dish (`CuisineLexicon`, 21 cuisines) | the set of cuisines | "kimchi carbonara", "bulgogi pizza", "Korean x Italian fusion" are all `fusion:italian+korean` |
| FLAVOR | only flavor words | the set of flavors | "sweet and spicy" |
| DISH | anything else that names food | its content words, stemmed and sorted | "birria tacos" = "taco birria" = "cheesy birria taco" |
| none | moods and occasions: "late night snack", "something to share with friends" | | counted as ignored, never a suggestion |

No list of known trends is consulted, so a fusion nobody anticipated ("Japanese x Mexican") is found the first time two cuisines
meet in searches. Filler, mood and flavor words are dropped from DISH keys; a small table folds spelling variants together
(shrimp/prawn, donut/doughnut, schezwan/szechuan, biryani/biriyani). A fusion is only detected when each cuisine is signalled by a word:
"butter chicken pizza" is read as Italian only, because "butter chicken" is not in the lexicon.

**Embedding clustering of paraphrases was tried and removed.** bge-small does not separate real rewordings from different dishes:
"french fries / potato chips" 0.73, "ice lolly / popsicle" 0.60 (same food) against "mushroom risotto / mushroom soup" 0.82 and
"iced coffee / iced tea" 0.83 (different food). No threshold merges the first without fusing the second
([docs/search-embedding-merge-evidence.md](search-embedding-merge-evidence.md); `TrendSimulationRealModelTest` fails if a future model
makes them separable, as a prompt to try again).

## What counts as rising (`TrendDetector`)

Counted in **searchers per day** (a person typing a phrase fifty times is one), last 7 days against the 28 before:

1. at least 8 searchers in the week, else `TOO_SMALL`
2. growth of at least 2x over its own baseline, `(recent/day + 0.25) / (baseline/day + 0.25)`; below that `STEADY`, or `FALLING` under 0.7x
3. active on at least 3 different days and no single day above 50% of the week, else `FLUKE`
4. otherwise `RISING`

Because the searcher key changes daily (Phase 1), "searchers" over several days means searcher-days: the same person on three days is three.
That is the price of not being able to follow anyone, and it is why the bars are set on days and volume rather than on unique people.

## Testing it without customers: the simulator

`POST /admin/search/simulate` (admin, and only with `search.sim.enabled=true`) writes 35 days of fake traffic, flagged `simulated`, with answers planted in it.
Each distinct query runs through the real search, so the unmet verdicts are real; only the people and the clock are invented.
`DELETE /admin/search/simulate` removes it. The trend job ignores simulated rows unless the flag is on.

Result on the real model ([full table](search-trend-simulation.md)): 2321 searches, 1908 searchers.

| Planted | Expected | Found |
|---|---|---|
| Korean x Italian fusion, 6 wordings, ramping over 12 days | RISING | RISING, 120 searchers, 22x, 100% of searches unmet |
| birria tacos, 4 wordings, ramping over 8 days | RISING | RISING, one trend, 38 searchers, 20x |
| Dubai chocolate, 45 people on one day | FLUKE | FLUKE (100% on one day) |
| ethiopian injera, 1 person a day | too small | TOO_SMALL |
| one device sending "free biryani" 60 times a day | not a trend | TOO_SMALL (7 searcher-days, not 420) |
| late night snack, something to share with friends (rising) | never a suggestion | ignored |
| pizza, biryani, burger, ramen, sweet and spicy, creamy and comforting | STEADY | STEADY |

Exactly two RISING phrases came out, both planted. This proves the detector against traffic built to be detectable; real search
behaviour will be messier, so the bars are properties (`search.trends.*`) to tune once there is real data.

## API and operations

| Call | Notes |
|---|---|
| `POST /admin/search/trends/run?asOf=` | runs the job now; also nightly at 03:10 (`search.trends.cron`) |
| `GET /admin/search/trends?status=RISING` | latest snapshot: phrase, kind, cuisines, searchers, baseline, growth, active days, unmet share, example wordings, reason |
| `POST` / `DELETE /admin/search/simulate` | demo traffic; 403 `SIMULATION_DISABLED` unless `search.sim.enabled` |

Snapshots (`search_trend`) keep phrases and counts only and are retained 30 days; they outlive the raw search text, which goes after 90.
Schema: `search_trend` is new and `search_event.simulated` is added by `ddl-auto: update` (default false, checked on a table that already had rows).

## Tests

`PhraseMinerTest` (8), `TrendDetectorTest` (7), `TrendJobIntegrationTest` (7: admin-only and off by default, planted trends through the endpoints,
re-run replaces the snapshot, simulated rows ignored unless on, clearing keeps real rows, 30 hammering requests plus 8 people = 9 searchers),
`TrendSimulationRealModelTest` (real model, skipped without it). Full backend suite: 215 passing. Also run live on Postgres.

---

# Phase 3: telling restaurants what to do about it

The nightly job now ends with `SuggestionService.generate`: for each rising phrase it works out which restaurants should hear about it and what to suggest.
Restaurants cannot see these yet (the owner screens and endpoints are Phase 4); admins can read them at `GET /admin/search/suggestions`.

## Who hears about a trend (`TrendMatcher`)

| Relation | Meaning | Becomes |
|---|---|---|
| HAS | a dish already is the thing: all words of a dish phrase, both cuisines of a fusion, all flavors with a strong tag | STOCK_UP or MAKE_DROP |
| CUISINE | no such dish, but the restaurant cooks a cuisine involved (declared, or at least two of its dishes point to it) | ADD_DISH |
| PARTIAL | no cuisine link, but dishes share some of a multi-word phrase's words (a taco place and "birria taco"), or one of a flavor pair | ADD_DISH, scored lower |
| NONE | nothing links them | nothing; the owner is not told |

An Indian kitchen is never told about Korean x Italian; a one-word phrase only matches a dish that really has the word.
A matching dish the owner switched off is reported as "turn it back on".

## The three suggestions

| Type | When | What the owner gets |
|---|---|---|
| ADD_DISH | rising, nothing on the menu, restaurant fits | a prefilled add-dish form: a dish-like name taken from how people actually typed it ("Kimchi Carbonara", not "Italian Korean fusion"), a short description, up to three flavor tags from the auto-tagger. For flavor trends, the two flavors to aim for |
| STOCK_UP | the restaurant has the dish | guidance to prepare more, with how many of those searches showed its dish and how many were tapped |
| MAKE_DROP | has the dish and the rise is strong (at least 20 searchers and 3x) | a prefilled Drop that matches the create-drop request: the dish and its price, slots about one day of search demand (10 to 60), tomorrow 18:00 to 21:00 |

**Phase 3 showed no sales estimate**, because searches were not tied to orders. Phase 5 changes that, but only where there is counted history; see below. Without it the copy still says so, and shows only counted things: searchers, growth, share of searches that found nothing, impressions and taps.

## Limits and lifecycle

- At most **3 new suggestions per owner per week**, across all their restaurants (a restaurant with no owner counts alone). Ranked by
  `log(1+searchers) x log(1+growth) x fit x (1 + unmet share for ADD_DISH)`: big, fast, unserved demand first. The rest wait for next week if still rising.
- A suggestion that is still open is refreshed in place on every run (new numbers, no duplicate).
- **Dismiss** hides it for 30 days. **Snooze** hides it for 7 days, then it returns with fresh numbers. **Acted** (owner added the dish or made the Drop) also holds off for 30 days.
- An open suggestion whose phrase has stopped rising expires after a week.
- Dismiss, snooze and acted take the set of restaurants the caller may act on and answer "nothing" for anything else, so ids cannot be probed or changed across restaurants.

## Result on simulated traffic (real model, demo catalog, [full text](search-suggestion-simulation.md))

| Restaurant | Suggestion |
|---|---|
| Bella Napoli (Italian) | ADD_DISH "Kimchi Carbonara": 120 searchers, 22x, 100% unmet; its menu appeared in all 120 searches and was tapped 16 times |
| Cravey Kitchen (declares Italian) | the same, 74 impressions |
| Casa Fuego (Mexican) | MAKE_DROP "Beef Birria Tacos": 38 searchers, 20x; tapped 3 times; 10 slots at 399 |
| Spice Route, Tokyo Ramen House, Bangkok Street and the rest | nothing |

Run live on Postgres: 3 created; running again refreshed the 3 and created none.

## Operations

| Call | Notes |
|---|---|
| `POST /admin/search/suggestions/generate?asOf=` | runs now; also nightly at 03:10 right after the trend job (`InsightsJob`) |
| `GET /admin/search/suggestions?status=NEW` | every suggestion, best first, with headline, text, evidence and the prefilled payload |

`owner_suggestion` is new (created by `ddl-auto: update`). The simulator now also records taps on about one search in five so the demo has impressions and taps to show.

## Open point for Phase 4: who is an owner?

A signed-in user and a `RestaurantOwner` are linked only by sharing an email address (`owner@cravey.com`), and nothing in the app checks that an owner touches only
their own restaurants (any OWNER can create a Drop for any restaurant id). The owner Insights screen must resolve the caller to their restaurants by that email and
pass them to the service, which is why the service already takes the allowed restaurant ids. Enforcing the same for menu items and Drops is a wider change, noted here rather than slipped in.

## Tests

`TrendMatcherTest` (9), `SuggestionServiceIntegrationTest` (11: fusion goes to Italian kitchens only, drop versus stock guidance, impressions and taps counted from real searches,
weekly cap per owner across restaurants and a new week lifting it, best-scoring kept, dismiss and cool-down, cross-restaurant protection, snooze and revival, acting, expiry,
admin-only), `SuggestionSimulationRealModelTest` (real model). Full backend suite: 236 passing.

---

# Phase 4: what owners and customers see

Phase 3's suggestions and Phase 2's trends are now on screen: an Insights tab for owners and "Trending cravings" chips for customers.

## Customers: Trending cravings (`GET /search/trending`, public)

Chips under the search bar. A chip appears only if the phrase is rising **and** at least one available dish matches it right now, so tapping a chip never shows an empty list
(the Korean x Italian fusion that no menu serves is a signal for restaurants, not a chip). A chip disappears when the dish is switched off.
Tapping runs the search for it. Chips hide while a search is showing.

The response is `label`, `query`, `kind`, `dishCount` and nothing else: no searcher counts, growth or share of unmet searches. Only phrases that already cleared the trend job's bars
(8+ searchers, 2x growth, 3+ days) can appear, so no chip reflects a handful of people. A contract test fixes the exact field set.

## Owners: the Insights tab (`/owner/insights`)

A fourth tab on the owner dashboard, "Insights (n)" with the count of waiting suggestions (loaded when the dashboard opens, not when the tab is tapped).
Each suggestion is a card: type, restaurant (when the owner has several), the text from Phase 3, the counted facts, and three buttons.

| Type | Main button | What happens |
|---|---|---|
| Add a dish | Add this dish | the normal add-dish form opens prefilled (name, description, flavor tags) for the suggestion's own restaurant; price is left for the owner; the suggestion closes only after the dish is saved |
| Keep more ready | Got it | closes it |
| Make it a Drop | Create this Drop | confirms title and slots (1 to 200), then creates the Drop |

"Later" snoozes for a week, "Not for me" dismisses for a month. Below the cards, "Trending across Cravey" lists every rising phrase with searchers and growth, and marks the ones no menu serves yet.

| Call | Notes |
|---|---|
| `GET /owner/insights` | the caller's restaurants, their open suggestions, all rising phrases |
| `POST /owner/insights/{id}/dismiss`, `/snooze`, `/acted` | `acted` is what the app calls after the owner saves the suggested dish |
| `POST /owner/insights/{id}/drop` `{title?, totalSlots?}` | creates the suggested Drop and closes the suggestion |

### Who is the caller (closing the Phase 3 open point, for this feature)

The caller's restaurants are looked up on the server from the signed-in email, through the owner record with the same email. A request never names a restaurant, so it cannot name one it does not own.
An admin sees all. An account with no owner record gets empty lists, not an error. Customers and signed-out callers are refused (403 and 401). Acting on another owner's suggestion, or an id that does not exist,
gets the same 404, so ids cannot be probed.

`POST .../drop` takes the restaurant, dish, price and window from the stored suggestion, never from the request; only title and slots can be changed, and slots are bounded. The Drop is created through the existing `DropService`.
The general gap is **not** closed: `POST /drops` and the menu-item endpoints still let any OWNER act on any restaurant id. That is a wider change to existing endpoints and is left for its own piece of work.

### Found and fixed while building it

- An expired or missing owner token on `/owner/...` redirected to a Google login instead of answering 401, because the 401 rule is an allowlist of API path prefixes. `/owner` is now on it (this also covers the existing `/owners` API).
- A 404 on dismiss or snooze (already gone) keeps the card removed instead of bringing back a dead card; any other failure restores it with the reason.

## Checked live (Postgres, real backend, Flutter web, simulated traffic)

- Customer home screen: chip "Birria Taco" under the search bar; tapping it searched "birria taco" and Casa Fuego's Beef Birria Tacos came first. The fusion was not offered.
- Owner (the seeded local test owner, who owns all nine demo restaurants): "Insights (3)"; cards for Bella Napoli and Cravey Kitchen (add a dish) and Casa Fuego (Drop).
  Add this dish opened the form prefilled with Bella Napoli's own menu sections; after entering a price and saving, the card closed, the count went to 2, and search then found "Kimchi Carbonara" first.
  Create this Drop made Drop 4 for Casa Fuego with dish 68, 399, 10 slots, tomorrow 18:00 to 21:00; both suggestions show ACTED in the database.
- The app's "Quick Demo Sign-In" is a client-side demo session with its own email, linked to no owner record here, so it correctly shows an empty list with the market view.
- Contract fixtures `test/fixtures/api_trending.json` and `api_owner_insights.json` are captured from this run.

## Tests

Backend `OwnerInsightsIntegrationTest` (11: each owner sees only their own, no-restaurant owner and admin, customers and visitors refused, cross-owner dismiss/snooze/acted/drop all 404 and untouched,
dismiss/snooze/acted, drop uses the suggestion's restaurant and dish and closes it, bounds and wrong type refused, chips show only orderable phrases and no numbers, tapping a chip always finds the dish,
chip vanishes when the dish is off, cap and ordering). Flutter: `insights_state_test` (12), `insights_widgets_test` (12), a prefill test in `add_dish_dialog_test`, two contract tests on the live fixtures.
Full suites: backend 247, Flutter 147.


---

# Phase 5: counting the orders search brings in

Phase 3 could say how often a dish was shown and tapped, but not whether anyone ordered it. Phase 5 counts delivered orders that came from search, so owners see what search is worth
and the suggestions can carry an estimate built from real history. The hard part is doing that without joining a person's order to what they typed.

## How it stays anonymous

| Step | What is kept | For how long |
|---|---|---|
| **Cart add** from a search result | the app sends the search id; the server checks the search really showed that dish to this searcher recently (same checks as a tap, honours do-not-track). The cart item then holds only the **phrase key**, like `dish:birria+taco`. Never the query, never the search id | until checkout, or 24 h |
| **Checkout** | a pending row: order id, restaurant, dish, phrase key, quantity, amount | until the order is settled; dropped after 3 days at most |
| **Delivered** (and paid) | a **daily count** per day, phrase, restaurant and dish: orders, units, revenue. **No order id, customer or search id.** The pending row is deleted | 400 days |
| Cancelled, refunded, unpaid and stale | discarded without counting | |

The order and a phrase meet in exactly one place (the pending row), for the hours an order is in flight. What lasts is a count. Counting at *delivery* rather than payment means a refund can never leave a
sale behind that nobody could find to undo. The cart response never echoes the phrase, a test checks the counts table has no identifying fields, and the raw search text is still deleted at 90 days while the counts remain.

An add that does not check out (a different searcher, a dish the search never showed, do-not-track, no search, an unknown search id, a mood search with no phrase) is simply not attributed; the add works as usual.
Only the cart path is covered: Drop reservations are a separate flow and are not attributed.

## Where it shows up

- **Owner Insights banner:** "Search brought you 69 delivered orders (₹34192) in the last 28 days", with the phrases that have at least 3 orders behind them (a phrase with fewer is not listed).
- **Stock-up and Drop suggestions** gain an estimate, shown as "about 6 orders a week" and explained in the text:
  this week's taps times the rate of delivered orders per tap over the last 4 weeks. It needs at least 3 counted orders and 10 taps behind it. If this phrase is too new, it falls back to the restaurant's own rate across all its search-driven
  orders, and says so. With less than that there is **no estimate**, and the card says "No sales estimate yet" instead of inventing one. "Add a dish" suggestions never get one: the dish does not exist yet, so there is no history.
- `POST /admin/search/attribution/settle` (admin) counts what is ready now; it also runs every ten minutes. A nightly job clears old cart attributions.

## Checked live (Postgres, the real app, the real flow)

The Flutter app in the browser: searched "birria tacos", tapped Beef Birria Tacos, added it from Casa Fuego's menu. The database then showed OPEN and ADD_TO_CART taps on the search, and the cart item held only `dish:birria+taco`.
Checkout created one pending row. Settling while the order was placed, paid, confirmed or out for delivery counted nothing ("still waiting"); after DELIVERED it counted 1, deleted the pending row, and left a daily row with no order, customer or search id.
The owner then saw 1 order, 399 revenue, and no per-phrase line (below 3 orders).

With simulated history on top, the owner screen showed the banner and, on Casa Fuego's Drop card, "about 6 orders a week": 7 delivered orders from 13 taps over 4 weeks, times 12 taps this week.

## Honest limits

- The simulator's tap and order rates are invented (the planted dish converts at 60% so the estimate path has something to show). Real rates will differ, which is why an estimate needs counted history and the thresholds are properties to tune.
- Attribution is last touch within the cart window: it says the search led to the add, not that the customer would not have ordered anyway.
- An estimate projects this week's taps at the past rate. It does not account for a trend growing or fading, and the card calls it "a rough guide, not a promise".

## Tests

Backend `OrderAttributionIntegrationTest` (10: delivered order becomes an anonymous count, counts table has no identifying fields, units do not inflate orders and several orders add up, six kinds of add that are not attributed, mood search,
cancelled/refunded/stale discarded, 24 h window and nightly purge, settling twice counts once, no trace without a search, admin-only settle) and `AttributionEstimateIntegrationTest` (5: real estimate with counted orders and its arithmetic, no estimate and an honest message without,
never for add-a-dish, owners see only their own restaurants' orders, simulated counts invisible when simulation is off). Flutter: `search_attribution_test` (11: the registry and its expiry, a tap remembers the search, the cart add sends the context only when it should and not twice),
estimate and banner widget tests, parsing tests, and the contract test now pins the live fixture's estimate and search orders. Full suites: backend 262, Flutter 163.
