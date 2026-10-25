package com.example.zomato.search;

import com.example.zomato.search.ParsedQuery.Facet;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.function.Predicate;

/**
 * Hybrid retrieval, no generation: several independent rankings are merged with Reciprocal Rank Fusion.
 *
 *   dense   - cosine of the whole craving against every dish vector
 *   facets  - each part of "sweet but also spicy" scored on its own, blended toward the weakest part so a dish has
 *             to satisfy all of them
 *   bm25    - exact words, plurals, prefixes and typos
 *   tags    - how many of the requested flavors the dish is tagged with (owner-confirmed counts fully)
 * then dishes that cover every requested flavor get a multiplicative lift. Without an embedding model the dense and
 * facet lists simply drop out and the rest still works.
 */
@Service
public class HybridSearchService {

    private static final int QUERY_CACHE = 500;

    private final SearchIndexService index;
    private final QueryParser parser;
    private final SearchProperties props;
    private final Map<String, float[]> queryCache = Collections.synchronizedMap(new LinkedHashMap<>(64, 0.75f, true) {
        @Override protected boolean removeEldestEntry(Map.Entry<String, float[]> e) { return size() > QUERY_CACHE; }
    });

    public HybridSearchService(SearchIndexService index, QueryParser parser, SearchProperties props) {
        this.index = index;
        this.parser = parser;
        this.props = props;
    }

    /**
     * What the customer is looking for: ALL (words, flavors and, failing both, meaning), DISH (every food word of the query is in the
     * dish's text: "pasta" means pasta dishes, nothing else) or CRAVING (taste and meaning, not names).
     */
    public enum Scope {
        ALL, DISH, CRAVING;

        /** The value of the {@code type} query parameter; anything unknown means ALL. */
        public static Scope fromParam(String s) {
            if (s == null) return ALL;
            return switch (s.trim().toLowerCase(Locale.ROOT)) {
                case "dish", "dishes" -> DISH;
                case "craving", "cravings" -> CRAVING;
                default -> ALL;
            };
        }
    }

    public record Request(String q, int k, Boolean veg, Float maxPrice, boolean openOnly, Scope scope) {
        public Request(String q, int k, Boolean veg, Float maxPrice, boolean openOnly) { this(q, k, veg, maxPrice, openOnly, Scope.ALL); }
    }

    /**
     * Which rankings take part; used by the evaluation to show what each one contributes. {@code relevantOnly} drops every dish that is not
     * actually relevant to the query (see {@link Scope}); the evaluation's ablations leave it off so their ranking numbers stay comparable.
     */
    public record Options(boolean dense, boolean facets, boolean bm25, boolean tags, boolean coverageBonus, boolean relevantOnly) {
        public Options(boolean dense, boolean facets, boolean bm25, boolean tags, boolean coverageBonus) { this(dense, facets, bm25, tags, coverageBonus, false); }
        public static final Options ALL = new Options(true, true, true, true, true, true);
    }

    public record Hit(DishDoc doc, double score, double raw, List<String> matchedTags, List<String> reasons, boolean ownerConfirmedAll) {}

    /**
     * How good the answer was, in absolute terms (the hit scores are relative to the best hit and cannot tell that).
     * Feeds the search log, where it separates cravings the menus satisfy from cravings nobody serves yet.
     *
     * @param relevantCount     dishes that matched on words, on requested flavors, or on meaning above the similarity threshold
     * @param bm25Candidates    dishes the keyword index matched at all
     * @param terms             content words in the craving (generic words such as "fusion" dropped)
     * @param unknownTerms      of those, how many no dish contains
     * @param fullMatches       dishes that contain every content word
     * @param bestSimilarity    cosine of the craving to the closest dish, null without the embedding model
     * @param topCoverage       how fully the first hit carries the requested flavors (1.0 = all, owner-confirmed), null if none requested
     * @param ownerCoveredTop3  how many of the first three hits carry every requested flavor with an owner-confirmed tag
     */
    public record Diagnostics(int relevantCount, int bm25Candidates, int terms, int unknownTerms, int fullMatches,
                              Double bestSimilarity, Double topCoverage, int ownerCoveredTop3) {
        public static final Diagnostics NONE = new Diagnostics(0, 0, 0, 0, 0, null, null, 0);
    }

    public record Result(ParsedQuery parsed, String mode, int total, List<Hit> hits, long tookMs, Diagnostics diagnostics) {}

    public Result search(Request req) { return search(req, Options.ALL); }

    public Result search(Request req, Options opt) {
        long t0 = System.nanoTime();
        index.ensureLoaded();
        ParsedQuery parsed = parser.parse(req.q());
        int k = Math.max(1, Math.min(req.k() <= 0 ? props.defaultK() : req.k(), props.maxK()));

        boolean vegOnly = Boolean.TRUE.equals(req.veg()) || parsed.vegOnly();
        Float maxPrice = req.maxPrice();
        if (parsed.maxPrice() != null) maxPrice = maxPrice == null ? parsed.maxPrice() : Float.valueOf(Math.min(maxPrice, parsed.maxPrice()));
        final Float priceCap = maxPrice;
        Predicate<DishDoc> accept = d -> d.available() && (!vegOnly || d.veg()) && (priceCap == null || d.price() <= priceCap)
                && (!req.openOnly() || d.restaurantOpen());

        Map<Integer, DishDoc> candidates = new HashMap<>();
        for (DishDoc d : index.allDocs()) if (accept.test(d)) candidates.put(d.itemId(), d);

        boolean semantic = index.provider().isSemantic() && index.vectors().size() > 0;
        int pool = Math.max(60, k * 6);
        List<Ranked> lists = new ArrayList<>();
        // why each dish counts as relevant, kept apart so the scope can choose which reasons it accepts
        Set<Integer> denseRelevant = new HashSet<>(), lexicalRelevant = new HashSet<>(), tagRelevant = new HashSet<>();
        Bm25Index.AllMatch dishMatch = new Bm25Index.AllMatch(false, Set.of());
        Double bestSimilarity = null;
        int bm25Candidates = 0;
        Bm25Index.FullMatch fullMatch = new Bm25Index.FullMatch(0, 0, 0);

        if (semantic && opt.dense()) {
            String wholeText = parsed.normalized().isBlank() ? parsed.original() : parsed.normalized();
            float[] whole = queryVector(wholeText);
            List<Bm25Index.Scored> denseScored = index.vectors().search(whole, candidates::containsKey, pool);
            lists.add(new Ranked("dense", props.denseWeight(), denseScored.stream().map(Bm25Index.Scored::id).toList()));
            if (!denseScored.isEmpty()) bestSimilarity = denseScored.get(0).score();
            for (Bm25Index.Scored d : denseScored) if (d.score() >= props.unmetSimilarity()) denseRelevant.add(d.id());

            if (opt.facets() && parsed.isMultiFacet()) {
                List<float[]> facetVectors = new ArrayList<>();
                for (Facet f : parsed.facets()) facetVectors.add(queryVector(f.text()));
                List<Bm25Index.Scored> blended = new ArrayList<>();
                for (int id : candidates.keySet()) {
                    double sum = 0, min = Double.MAX_VALUE;
                    boolean ok = true;
                    for (float[] fv : facetVectors) {
                        double sim = index.vectors().similarity(id, fv);
                        if (Double.isNaN(sim)) { ok = false; break; }
                        sum += sim;
                        min = Math.min(min, sim);
                    }
                    if (ok) blended.add(new Bm25Index.Scored(id, 0.5 * (sum / facetVectors.size()) + 0.5 * min));
                }
                blended.sort((a, b) -> Double.compare(b.score(), a.score()));
                lists.add(new Ranked("facets", props.facetWeight(), blended.stream().limit(pool).map(Bm25Index.Scored::id).toList()));
            }
        }

        if (opt.bm25()) {
            String text = parsed.normalized().isBlank() ? parsed.original() : parsed.normalized();
            // every keyword match counts for relevance, however far down; only the top of the list feeds the fusion
            List<Bm25Index.Scored> lexicalAll = index.bm25().search(text, candidates::containsKey, Math.max(pool, candidates.size()));
            List<Bm25Index.Scored> lexical = lexicalAll.size() > pool ? lexicalAll.subList(0, pool) : lexicalAll;
            if (!lexical.isEmpty()) lists.add(new Ranked("bm25", props.bm25Weight(), lexical.stream().map(Bm25Index.Scored::id).toList()));
            bm25Candidates = lexicalAll.size();
            fullMatch = index.bm25().fullMatch(text, candidates::containsKey);
            lexicalAll.forEach(l -> lexicalRelevant.add(l.id()));
            if (req.scope() == Scope.DISH) dishMatch = index.bm25().matchAll(text, PhraseMiner::isFlavorOrMood, candidates::containsKey);
        }

        Set<Flavor> wanted = parsed.flavors();
        if (opt.tags() && !wanted.isEmpty()) {
            List<Bm25Index.Scored> byTags = new ArrayList<>();
            for (DishDoc d : candidates.values()) {
                double c = coverage(d, wanted);
                if (c > 0) byTags.add(new Bm25Index.Scored(d.itemId(), c));
                if (c >= 0.5) tagRelevant.add(d.itemId());
            }
            byTags.sort(Comparator.comparingDouble(Bm25Index.Scored::score).reversed().thenComparingInt(Bm25Index.Scored::id));
            lists.add(new Ranked("tags", props.tagWeight(), byTags.stream().limit(pool).map(Bm25Index.Scored::id).toList()));
        }

        Map<Integer, Double> fused = new HashMap<>();
        for (Ranked r : lists) {
            for (int rank = 0; rank < r.ids().size(); rank++) {
                fused.merge(r.ids().get(rank), r.weight() / (props.rrfK() + rank + 1), Double::sum);
            }
        }
        if (opt.coverageBonus() && !wanted.isEmpty()) {
            for (var e : fused.entrySet()) {
                e.setValue(e.getValue() * (1.0 + props.coverageBonus() * coverage(candidates.get(e.getKey()), wanted)));
            }
        }

        List<Map.Entry<Integer, Double>> ranked = new ArrayList<>(fused.entrySet());
        ranked.sort(Map.Entry.<Integer, Double>comparingByValue().reversed().thenComparing(Map.Entry.comparingByKey()));

        // the dense list returns every dish ranked by similarity, so without a cutoff "pasta" would end with whatever is nearest in meaning
        // (tiramisu); only dishes that are relevant for a reason this scope accepts are shown
        if (opt.relevantOnly()) {
            Set<Integer> allowed = allowedIds(req.scope(), semantic && opt.dense(), dishMatch, lexicalRelevant, tagRelevant, denseRelevant);
            if (allowed != null) ranked.removeIf(e -> !allowed.contains(e.getKey()));
        }
        Set<Integer> relevant = new HashSet<>(denseRelevant);
        relevant.addAll(lexicalRelevant);
        relevant.addAll(tagRelevant);
        double best = ranked.isEmpty() ? 1.0 : ranked.get(0).getValue();

        Set<String> queryTerms = new HashSet<>(Bm25Index.tokenize(parsed.normalized()));
        List<Hit> hits = new ArrayList<>();
        for (var e : ranked.subList(0, Math.min(k, ranked.size()))) {
            DishDoc d = candidates.get(e.getKey());
            hits.add(new Hit(d, e.getValue() / best, e.getValue(), matchedTags(d, wanted), reasons(d, wanted, queryTerms),
                    !wanted.isEmpty() && wanted.stream().allMatch(f -> Boolean.TRUE.equals(d.ownerTags().get(f)))));
        }
        long took = (System.nanoTime() - t0) / 1_000_000;
        Double topCoverage = wanted.isEmpty() || hits.isEmpty() ? null : coverage(hits.get(0).doc(), wanted);
        int ownerTop3 = (int) hits.stream().limit(3).filter(Hit::ownerConfirmedAll).count();
        Diagnostics diag = new Diagnostics(relevant.size(), bm25Candidates, fullMatch.terms(), fullMatch.unknown(), fullMatch.fullMatches(), bestSimilarity, topCoverage, ownerTop3);
        return new Result(parsed, semantic && opt.dense() ? "HYBRID" : "KEYWORD", ranked.size(), hits, took, diag);
    }

    /**
     * The dishes a scope may show, or null for "no restriction".
     * ALL: dishes matching the words or the requested flavors; only when there is neither does meaning decide (mood searches such as "late night snack").
     * DISH: dishes containing every food word of the query (flavor and mood words do not count as food words); with no food word it behaves like ALL.
     * CRAVING: dishes carrying the requested flavors, or close in meaning; names alone do not qualify. Without the embedding model, words stand in for meaning.
     */
    private static Set<Integer> allowedIds(Scope scope, boolean semantic, Bm25Index.AllMatch dishMatch, Set<Integer> lexical, Set<Integer> tags, Set<Integer> dense) {
        Set<Integer> allowed = new HashSet<>();
        switch (scope == null ? Scope.ALL : scope) {
            case DISH -> {
                if (dishMatch.hadTerms()) return new HashSet<>(dishMatch.ids());
                return allowedIds(Scope.ALL, semantic, dishMatch, lexical, tags, dense);
            }
            case CRAVING -> {
                allowed.addAll(tags);
                allowed.addAll(dense);
                if (!semantic) allowed.addAll(lexical);
            }
            default -> {
                allowed.addAll(lexical);
                allowed.addAll(tags);
                if (allowed.isEmpty()) allowed.addAll(dense);
            }
        }
        return allowed;
    }

    private float[] queryVector(String text) {
        String key = text.toLowerCase(Locale.ROOT).trim();
        float[] cached = queryCache.get(key);
        if (cached != null) return cached;
        float[] v = index.provider().embedQuery(text);
        queryCache.put(key, v);
        return v;
    }

    /** Share of the requested flavors the dish carries, weighted by tag confidence (owner-confirmed = 1.0). */
    static double coverage(DishDoc d, Set<Flavor> wanted) {
        if (d == null || wanted.isEmpty()) return 0;
        double sum = 0;
        for (Flavor f : wanted) sum += d.tags().getOrDefault(f, 0.0);
        return sum / wanted.size();
    }

    private static List<String> matchedTags(DishDoc d, Set<Flavor> wanted) {
        List<String> out = new ArrayList<>();
        for (Flavor f : Flavor.values()) if (wanted.contains(f) && d.tags().containsKey(f)) out.add(f.id());
        return out;
    }

    /** Plain-language "why": built only from real matches (tags, words), never generated. */
    private static List<String> reasons(DishDoc d, Set<Flavor> wanted, Set<String> queryTerms) {
        List<String> why = new ArrayList<>();
        List<String> owner = new ArrayList<>(), auto = new ArrayList<>();
        for (Flavor f : Flavor.values()) {
            if (!wanted.contains(f) || !d.tags().containsKey(f)) continue;
            (Boolean.TRUE.equals(d.ownerTags().get(f)) ? owner : auto).add(f.id());
        }
        if (!owner.isEmpty()) why.add("Tagged " + String.join(" + ", owner) + " by the restaurant");
        if (!auto.isEmpty()) why.add("Looks " + String.join(" + ", auto) + " from its description");
        Set<String> hay = new LinkedHashSet<>();
        for (String t : Bm25Index.tokenize(d.name() + " " + nz(d.ingredients()) + " " + nz(d.description()))) if (queryTerms.contains(t)) hay.add(t);
        if (!hay.isEmpty()) why.add("Mentions " + String.join(", ", hay));
        if (wanted.contains(Flavor.SPICY) && d.spiceLevel() != null && d.spiceLevel() >= 2) why.add("Spice level " + d.spiceLevel() + " of 4");
        return why;
    }

    private static String nz(String s) { return s == null ? "" : s; }

    private record Ranked(String name, double weight, List<Integer> ids) {}
}
