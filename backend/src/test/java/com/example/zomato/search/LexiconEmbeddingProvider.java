package com.example.zomato.search;

import java.util.EnumMap;
import java.util.Locale;
import java.util.Map;

/**
 * Deterministic stand-in for the real model in tests: flavor words (and the cue words dishes use for them) land on a
 * shared dimension per flavor, everything else is hashed into a few buckets. Good enough to exercise the pipeline
 * (ranking, fusion, facets, filters); real semantic quality is measured separately against the actual model.
 */
public final class LexiconEmbeddingProvider implements EmbeddingProvider {

    private static final int BUCKETS = 48;
    private final Map<Flavor, java.util.Set<String>> words = new EnumMap<>(Flavor.class);

    public LexiconEmbeddingProvider() {
        for (Flavor f : Flavor.values()) {
            java.util.Set<String> w = new java.util.HashSet<>(f.querySynonyms());
            f.cues().keySet().forEach(c -> w.addAll(java.util.Arrays.asList(c.split(" "))));
            words.put(f, w);
        }
    }

    @Override public float[] embedDocument(String text) { return embed(text); }
    @Override public float[] embedQuery(String text) { return embed(text); }
    @Override public int dimension() { return Flavor.values().length + BUCKETS; }
    @Override public String modelVersion() { return "lexicon-test-1"; }

    private float[] embed(String text) {
        float[] v = new float[dimension()];
        for (String tok : text.toLowerCase(Locale.ROOT).split("[^a-z]+")) {
            if (tok.length() < 3) continue;
            boolean flavored = false;
            for (Flavor f : Flavor.values()) {
                if (words.get(f).contains(tok)) {
                    v[f.ordinal()] += 1.0f;
                    flavored = true;
                }
            }
            if (!flavored) v[Flavor.values().length + Math.floorMod(tok.hashCode(), BUCKETS)] += 0.25f;
        }
        return OnnxEmbeddingProvider.normalize(v);
    }
}
