package com.example.zomato.search;

/**
 * Turns text into a unit-length vector. Documents and queries are embedded differently on purpose
 * (retrieval models like bge expect an instruction prefix on the query side only).
 */
public interface EmbeddingProvider {

    float[] embedDocument(String text);

    float[] embedQuery(String text);

    int dimension();

    /** Changes whenever vectors from an older version must not be compared with new ones. */
    String modelVersion();

    /** False for the do-nothing provider used when no model is installed: search then runs keyword + tags only. */
    default boolean isSemantic() { return true; }
}
