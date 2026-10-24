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
