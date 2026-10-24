package com.example.zomato.search;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.InputStream;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/** Relevance judgements and ranking metrics shared by the evaluation tests. */
final class SearchEvalSupport {

    record Query(String group, String q, JsonNode spec) {}

    record Scores(double recall, double mrr, double ndcg, int queries) {}

    static List<Query> queries() throws Exception {
        List<Query> out = new ArrayList<>();
        try (InputStream in = SearchEvalSupport.class.getResourceAsStream("/search/eval-queries.json")) {
            for (JsonNode n : new ObjectMapper().readTree(in)) out.add(new Query(n.get("group").asText(), n.get("q").asText(), n));
        }
        return out;
    }

    /** A dish is relevant to a query if it satisfies every condition the query's spec states, judged from the seed ground truth. */
    static boolean relevant(Query query, DishDoc d, Set<String> truthTags) {
        JsonNode s = query.spec();
        if (s.has("allOf") && !allIn(s.get("allOf"), truthTags)) return false;
        if (s.has("anyOf") && !anyIn(s.get("anyOf"), truthTags)) return false;
        if (s.has("veg") && s.get("veg").asBoolean() && !d.veg()) return false;
        if (s.has("temp") && !s.get("temp").asText().equalsIgnoreCase(d.servingTemp())) return false;
        if (s.has("maxPrice") && d.price() > s.get("maxPrice").asDouble()) return false;
        if (s.has("minSpice") && (d.spiceLevel() == null || d.spiceLevel() < s.get("minSpice").asInt())) return false;
        if (s.has("maxSpice") && (d.spiceLevel() == null || d.spiceLevel() > s.get("maxSpice").asInt())) return false;
        if (s.has("categoryAny") && !containsAny(s.get("categoryAny"), d.category(), true)) return false;
        if (s.has("nameAny") && !containsAny(s.get("nameAny"), d.name(), false)) return false;
        if (s.has("moodAny") && !containsAny(s.get("moodAny"), d.mood(), false)) return false;
        return true;
    }

    private static boolean allIn(JsonNode arr, Set<String> tags) {
        for (JsonNode n : arr) if (!tags.contains(n.asText())) return false;
        return true;
    }

    private static boolean anyIn(JsonNode arr, Set<String> tags) {
        for (JsonNode n : arr) if (tags.contains(n.asText())) return true;
        return false;
    }

    private static boolean containsAny(JsonNode arr, String text, boolean exact) {
        if (text == null) return false;
        String t = text.toLowerCase(Locale.ROOT);
        for (JsonNode n : arr) {
            String v = n.asText().toLowerCase(Locale.ROOT);
            if (exact ? t.equals(v) : t.contains(v)) return true;
        }
        return false;
    }

    static Scores score(List<Integer> ranked, Set<Integer> relevant) {
        int k = Math.min(10, ranked.size());
        int hits = 0;
        double dcg = 0, mrr = 0;
        for (int i = 0; i < k; i++) {
            if (relevant.contains(ranked.get(i))) {
                hits++;
                dcg += 1.0 / (Math.log(i + 2) / Math.log(2));
                if (mrr == 0) mrr = 1.0 / (i + 1);
            }
        }
        double ideal = 0;
        for (int i = 0; i < Math.min(10, relevant.size()); i++) ideal += 1.0 / (Math.log(i + 2) / Math.log(2));
        return new Scores((double) hits / Math.min(10, relevant.size()), mrr, ideal == 0 ? 0 : dcg / ideal, 1);
    }

    static Scores mean(List<Scores> all) {
        return new Scores(all.stream().mapToDouble(Scores::recall).average().orElse(0),
                all.stream().mapToDouble(Scores::mrr).average().orElse(0),
                all.stream().mapToDouble(Scores::ndcg).average().orElse(0), all.size());
    }

    static Map<String, Scores> byGroup(Map<Query, Scores> perQuery) {
        Map<String, List<Scores>> g = new LinkedHashMap<>();
        for (var e : perQuery.entrySet()) g.computeIfAbsent(e.getKey().group(), k -> new ArrayList<>()).add(e.getValue());
        Map<String, Scores> out = new LinkedHashMap<>();
        g.forEach((k, v) -> out.put(k, mean(v)));
        out.put("ALL", mean(perQuery.values().stream().collect(Collectors.toList())));
        return out;
    }
}
