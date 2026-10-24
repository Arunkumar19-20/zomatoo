package com.example.zomato.search;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.function.IntPredicate;

/**
 * In-memory BM25 over dish text. Handles exact words ("margherita"), plurals (light stemming), prefixes and small
 * typos ("margarita" finds "margherita"), which the embedding side is weaker at. Small enough (tens of thousands
 * of dishes) that rebuilding or updating it per dish is trivial.
 */
public final class Bm25Index {

    private static final double K1 = 1.2;
    private static final double B = 0.75;
    private static final Set<String> STOP = Set.of("a", "an", "the", "of", "and", "or", "with", "in", "on", "for", "to", "at", "by",
            "is", "it", "its", "this", "that", "from", "into", "our", "your", "served", "style", "made");

    private record Doc(Map<String, Integer> tf, int length) {}

    private final Map<Integer, Doc> docs = new HashMap<>();
    private final Map<String, Integer> df = new HashMap<>();
    private long totalLength;

    public synchronized void upsert(int id, Map<String, Integer> weightedText) {
        remove(id);
        Map<String, Integer> tf = new HashMap<>();
        int len = 0;
        for (var e : weightedText.entrySet()) {
            for (String tok : tokenize(e.getKey())) {
                tf.merge(tok, e.getValue(), Integer::sum);
                len += e.getValue();
            }
        }
        docs.put(id, new Doc(tf, len));
        totalLength += len;
        for (String t : tf.keySet()) df.merge(t, 1, Integer::sum);
    }

    public synchronized void remove(int id) {
        Doc old = docs.remove(id);
        if (old == null) return;
        totalLength -= old.length();
        for (String t : old.tf().keySet()) {
            df.computeIfPresent(t, (k, v) -> v <= 1 ? null : v - 1);
        }
    }

    public synchronized void clear() {
        docs.clear();
        df.clear();
        totalLength = 0;
    }

    public synchronized int size() { return docs.size(); }

    /** Scored hits, best first, over docs accepted by the filter. */
    public synchronized List<Scored> search(String query, IntPredicate filter, int limit) {
        List<String> terms = tokenize(query);
        if (terms.isEmpty() || docs.isEmpty()) return List.of();

        Map<String, Double> weights = new HashMap<>();
        for (String t : terms) {
            if (df.containsKey(t)) {
                weights.merge(t, 1.0, Math::max);
            } else {
                // a word the menu does not contain is most likely a typo of a rare word, so trust the close match
                for (String near : nearTerms(t)) weights.merge(near, 0.9, Math::max);
            }
        }
        if (weights.isEmpty()) return List.of();

        double avgLen = (double) totalLength / docs.size();
        List<Scored> scored = new ArrayList<>();
        for (var e : docs.entrySet()) {
            if (!filter.test(e.getKey())) continue;
            Doc d = e.getValue();
            double score = 0;
            for (var w : weights.entrySet()) {
                Integer tf = d.tf().get(w.getKey());
                if (tf == null) continue;
                double idf = Math.log(1 + (docs.size() - df.get(w.getKey()) + 0.5) / (df.get(w.getKey()) + 0.5));
                score += w.getValue() * idf * (tf * (K1 + 1)) / (tf + K1 * (1 - B + B * d.length() / avgLen));
            }
            if (score > 0) scored.add(new Scored(e.getKey(), score));
        }
        scored.sort((a, b) -> Double.compare(b.score(), a.score()));
        return scored.size() > limit ? new ArrayList<>(scored.subList(0, limit)) : scored;
    }

    /** Index terms within a small edit distance, or sharing a prefix, of an unknown query term. */
    private Set<String> nearTerms(String term) {
        Set<String> out = new HashSet<>();
        for (String known : df.keySet()) {
            if (term.length() >= 3 && known.length() > term.length() && known.startsWith(term)) {
                out.add(known);
            } else if (term.length() >= 5 && Math.abs(known.length() - term.length()) <= 2
                    && editDistance(term, known) <= (term.length() >= 8 ? 2 : 1)) {
                out.add(known);
            }
        }
        return out;
    }

    public static List<String> tokenize(String text) {
        List<String> out = new ArrayList<>();
        for (String raw : text.toLowerCase(Locale.ROOT).split("[^a-z0-9]+")) {
            if (raw.length() < 2 || STOP.contains(raw)) continue;
            out.add(stem(raw));
        }
        return out;
    }

    static String stem(String t) {
        // brownie / brownies and berry / berries meet in the middle: both end up as ...y
        if (t.length() > 4 && t.endsWith("ies")) return t.substring(0, t.length() - 3) + "y";
        if (t.length() > 4 && t.endsWith("ie")) return t.substring(0, t.length() - 2) + "y";
        if (t.length() > 5 && t.endsWith("es") && (t.endsWith("ches") || t.endsWith("shes") || t.endsWith("sses") || t.endsWith("xes")))
            return t.substring(0, t.length() - 2);
        if (t.length() > 3 && t.endsWith("s") && !t.endsWith("ss") && !t.endsWith("us")) return t.substring(0, t.length() - 1);
        return t;
    }

    static int editDistance(String a, String b) {
        int[] prev = new int[b.length() + 1];
        int[] cur = new int[b.length() + 1];
        for (int j = 0; j <= b.length(); j++) prev[j] = j;
        for (int i = 1; i <= a.length(); i++) {
            cur[0] = i;
            for (int j = 1; j <= b.length(); j++) {
                int cost = a.charAt(i - 1) == b.charAt(j - 1) ? 0 : 1;
                cur[j] = Math.min(Math.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
            }
            int[] tmp = prev;
            prev = cur;
            cur = tmp;
        }
        return prev[b.length()];
    }

    public record Scored(int id, double score) {}
}
