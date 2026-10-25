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
