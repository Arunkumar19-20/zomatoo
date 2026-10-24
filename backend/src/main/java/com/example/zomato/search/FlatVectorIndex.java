package com.example.zomato.search;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.IntPredicate;

/**
 * Brute-force cosine search over unit vectors. For tens of thousands of dishes this takes a few milliseconds and
 * needs no extra database; it sits behind this small class so pgvector or an ANN index can replace it later.
 */
public final class FlatVectorIndex {

    private final Map<Integer, float[]> vectors = new ConcurrentHashMap<>();

    public void put(int id, float[] unitVector) { vectors.put(id, unitVector); }
    public void remove(int id) { vectors.remove(id); }
    public void clear() { vectors.clear(); }
    public int size() { return vectors.size(); }
    public boolean contains(int id) { return vectors.containsKey(id); }

    /** Cosine similarity of the query to one stored vector, or NaN if the dish has none. */
    public double similarity(int id, float[] query) {
        float[] v = vectors.get(id);
        return v == null ? Double.NaN : dot(v, query);
    }

    public List<Bm25Index.Scored> search(float[] query, IntPredicate filter, int limit) {
        List<Bm25Index.Scored> all = new ArrayList<>();
        for (var e : vectors.entrySet()) {
            if (filter.test(e.getKey())) all.add(new Bm25Index.Scored(e.getKey(), dot(e.getValue(), query)));
        }
        all.sort((a, b) -> Double.compare(b.score(), a.score()));
        return all.size() > limit ? new ArrayList<>(all.subList(0, limit)) : all;
    }

    static double dot(float[] a, float[] b) {
        int n = Math.min(a.length, b.length);
        double s = 0;
        for (int i = 0; i < n; i++) s += a[i] * b[i];
        return s;
    }
}
