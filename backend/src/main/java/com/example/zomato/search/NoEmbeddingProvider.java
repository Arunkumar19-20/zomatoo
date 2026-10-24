package com.example.zomato.search;

/** Used when the model files are not installed. Search degrades to keyword + tag retrieval. */
public final class NoEmbeddingProvider implements EmbeddingProvider {

    @Override public float[] embedDocument(String text) { throw new UnsupportedOperationException("no embedding model installed"); }
    @Override public float[] embedQuery(String text) { throw new UnsupportedOperationException("no embedding model installed"); }
    @Override public int dimension() { return 0; }
    @Override public String modelVersion() { return "none"; }
    @Override public boolean isSemantic() { return false; }
}
