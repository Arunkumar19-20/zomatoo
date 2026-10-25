# Craving search: how it works and how well

"Something sweet but also spicy" in the search bar, the top dishes out. No LLM is involved: it is retrieval only (the R
of RAG), so every result shows why it matched and nothing is generated.

## Pipeline

```
 dish saved by an owner ──▶ flavor tags (owner-picked, or suggested) ──▶ text + tags embedded (bge-small, 384 dims)
                                                                   └──▶ BM25 index (name x3, tags x2, ingredients x2, ...)

 query ──▶ QueryParser: strip filler, pull out "vegetarian" / "under 300", split "sweet but also spicy" into facets
       ├─▶ dense:   cosine of the whole craving against every dish vector
       ├─▶ facets:  each part scored alone, blended toward the weakest part (a dish must satisfy all of them)
       ├─▶ bm25:    exact words, plurals, prefixes, typos
       └─▶ tags:    share of the requested flavors the dish is tagged with (owner-confirmed counts fully)
       ──▶ Reciprocal Rank Fusion ──▶ lift for dishes that cover every requested flavor ──▶ top k with reasons
```

Code: [`backend/.../search`](../backend/src/main/java/com/example/zomato/search). Without the model files the dense and
facet lists drop out and the rest keeps working (`mode: KEYWORD` in the response).

- Model: BAAI/bge-small-en-v1.5 (MIT), ONNX Runtime in the backend JVM, a plain-Java WordPiece tokenizer (no native
  tokenizer download). Install it with `scripts/search/download_model.sh`.
- Latency on a laptop with 130 dishes: 0 to 25 ms server side per query (queries are embedded once and cached).

## What was measured

Data: 126 synthetic dishes across 8 demo restaurants (written for this project), 54 craving queries in five groups
(flavor combinations, single flavors, filters, paraphrases with no flavor word, dish names), relevance judged from the
tags an owner would pick. Metrics are recall@10, MRR and nDCG@10, shown as `recall / MRR / nDCG`.

### Dishes tagged automatically (the honest condition: no owner tags)

| condition | combo | single | constraint | intent | name | ALL |
|---|---|---|---|---|---|---|
| keyword only (BM25) | 0.56 / 0.77 / 0.56 | 0.66 / 0.77 / 0.66 | 0.70 / 0.90 / 0.69 | 0.70 / 0.78 / 0.69 | 1.00 / 0.90 / 0.93 | 0.71 / 0.82 / 0.69 |
| dense only | 0.34 / 0.68 / 0.37 | 0.59 / 0.82 / 0.63 | 0.60 / 0.76 / 0.59 | 0.53 / 0.61 / 0.51 | 1.00 / 0.93 / 0.95 | 0.59 / 0.75 / 0.59 |
| hybrid, no tags | 0.44 / 0.81 / 0.48 | 0.73 / 0.90 / 0.76 | 0.77 / 0.74 / 0.70 | 0.69 / 0.88 / 0.70 | 1.00 / 0.95 / 0.96 | 0.70 / 0.86 / 0.70 |
| hybrid + tags | 0.51 / 0.89 / 0.54 | 0.83 / 1.00 / 0.86 | 0.70 / 0.81 / 0.71 | 0.75 / 0.82 / 0.72 | 1.00 / 0.95 / 0.96 | 0.74 / 0.90 / 0.74 |
| **full (+ coverage lift)** | 0.54 / 0.86 / 0.58 | 0.83 / 1.00 / 0.86 | 0.67 / 0.94 / 0.71 | 0.71 / 0.82 / 0.70 | 1.00 / 0.95 / 0.96 | **0.73 / 0.90 / 0.75** |

### Dishes tagged by their owners (an upper bound)

| condition | ALL |
|---|---|
| keyword only (BM25) | 0.88 / 0.88 / 0.85 |
| dense only | 0.61 / 0.77 / 0.61 |
| **full** | **0.89 / 0.96 / 0.89** |

Read this one with care: relevance is judged from the same owner tags the system matches on, so it measures how well
the ranking uses good tags, not how well it guesses.

### What the numbers say

- The first result is right far more often with the hybrid (MRR 0.90 vs 0.82 with keywords alone, 0.96 vs 0.88 with
  owner tags). Recall@10 is close to keyword-only: most of the gain is ranking, not finding.
- **Embeddings alone are the weakest part** here (0.59 recall). A small sentence model is poor at "sweet and spicy" as
  a pair; it helps on paraphrases ("something warm and cozy for a rainy day") and for ordering, not as the main signal.
- Good tags matter most: owner tags lift recall from 0.73 to 0.89 and MRR from 0.90 to 0.96. That is why the owner form
  asks for at least two flavor tags and suggests them as the owner types.
- Typo handling works through the keyword side ("margarita pizza" is in the name group, which scores recall 1.00: both Margherita pizzas are in the top ten).

### Auto-tagger

- Against the owner tags of the demo dishes: 68% precision, 66% recall overall. Strong on sweet (97% / 77%), spicy (80% / 91%) and smoky;
  weak on savory and comfort (recall 46% and 34%). Prototype similarity on its own: 66% precision, 30% recall.
- **External check on data nobody here wrote** (Indian Food 101, 221 dishes labelled sweet or spicy, name + ingredients + course only):
  when it commits to exactly one of the two it is right 94% of the time (156 of 166); it recognises 98% of the sweet
  dishes but only 56% of the spicy ones, because that dataset calls most main courses spicy without saying why.
- "sour" is never chosen by owners in the demo catalog (they use "tangy"), so the tagger's sour suggestions count as wrong there.

## What a search returns: relevance cutoff and filters

The ranking above decides the *order*. It used to decide the *membership* too, which was wrong: the meaning-based list scores every dish, so a short
list of real matches was padded with whatever was nearest in meaning. A search for "pasta" returned the six pasta dishes and then Mushroom Risotto,
Greek Salad, Caprese Salad and Tiramisu, under a count of "Top 10 of 101".

Now a dish is shown only if it is relevant for a reason the search accepts:

| Filter (`type`) | A dish is shown when |
|---|---|
| none (everything) | it matches the query's words, or carries the requested flavors; only if there is neither does meaning decide (this is what keeps "late night snack" working) |
| `dish` | it contains **every** food word of the query in its name, description, ingredients or category. Flavor and mood words ("spicy", "late night") and joining words ("but", "also") are not required, so "spicy noodles" means noodle dishes and a craving sentence with no food in it behaves like everything |
| `craving` | it carries the requested flavors or is close in meaning; a name match alone does not qualify |

Restaurants is not a dish search. The app lists the restaurants that are relevant to the words typed, best first, each with the reason it is there:
a name match ranks first, then cuisine, then a restaurant that serves a matching dish ("Serves Pasta Primavera and 2 more"), then the address. Every word of the query
has to be found somewhere in the restaurant, so "italian pasta" is not every Italian place plus every pasta dish. Words such as "best", "near me" and "restaurants" are ignored.

A dish result is described by its restaurant's cuisine ("Italian", at most two chips), not by taste tags. The taste tags (Creamy, Spicy, ...) show only under the Cravings filter,
where taste is the point.

Checked on the real model with the 126 demo dishes: "pasta" gives 6 pasta dishes and no Tiramisu, "pizza" 5, "birria tacos" with `dish` gives only Beef Birria
Tacos (everything also shows Tacos al Pastor), "injera" gives nothing in any filter. The evaluation above is unchanged to the second decimal for every query group,
because its "full" row already runs with the cutoff: the cutoff removes irrelevant dishes from the tail, not relevant ones from the top ten.
The log's "was this served?" verdict is untouched by it: it still judges relevance by words, flavors and meaning together, whichever filter was shown.

## Tried and not kept

| idea | result |
|---|---|
| append the flavor's meaning to the query before embedding it | no gain (0.73 / 0.91 / 0.75 vs 0.74 / 0.91 / 0.76) |
| second, short "tastes sweet, spicy" vector per dish | +0.02 recall, +0.02 nDCG; not worth a second vector per dish |
| fusion weights (72-point grid, scored with and without owner tags) | flat: best vs defaults differ by 0.016 / 0.010 nDCG, worst grid point 0.745 / 0.879. The weights are not a sensitive knob, so the defaults stay |

## Limits to keep in mind

- The catalog and the queries were written by the same person who built the system. They show that the pipeline works
  and which parts matter; they are not a benchmark. A real catalog with real queries will score differently.
- 54 queries: differences of a few hundredths are noise.
- The index lives in memory and is rebuilt at start-up. That is fine up to tens of thousands of dishes on one server;
  several servers would need a shared index (pgvector is the obvious next step; `FlatVectorIndex` is the seam).

## Reproduce

```bash
scripts/search/download_model.sh            # 133 MB model, once
scripts/search/fetch_indian_food.sh         # optional external tagger check
cd backend && ./mvnw test -Dtest=RealModelSearchEvalTest   # writes target/search-eval.md
```
