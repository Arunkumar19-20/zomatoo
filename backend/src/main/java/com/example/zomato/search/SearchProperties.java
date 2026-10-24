package com.example.zomato.search;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/** Tunables for dish search, all under {@code search.*}. */
@Component
public class SearchProperties {

    /** Where model.onnx and vocab.txt live (see scripts/search/download_model.sh). */
    @Value("${search.model-dir:models/bge-small-en-v1.5}")
    private String modelDir;

    @Value("${search.default-k:10}")
    private int defaultK;

    @Value("${search.max-k:50}")
    private int maxK;

    /** Reciprocal Rank Fusion constant. */
    @Value("${search.rrf-k:60}")
    private int rrfK;

    @Value("${search.weight.dense:1.0}")
    private double denseWeight;

    @Value("${search.weight.facets:1.2}")
    private double facetWeight;

    @Value("${search.weight.bm25:0.8}")
    private double bm25Weight;

    @Value("${search.weight.tags:1.0}")
    private double tagWeight;

    /** How much covering every requested flavor lifts a dish (1 + bonus * coverage). */
    @Value("${search.coverage-bonus:0.6}")
    private double coverageBonus;

    @Value("${search.rate-limit-per-minute:60}")
    private int rateLimitPerMinute;

    public String modelDir() { return modelDir; }
    public int defaultK() { return defaultK; }
    public int maxK() { return maxK; }
    public int rrfK() { return rrfK; }
    public double denseWeight() { return denseWeight; }
    public double facetWeight() { return facetWeight; }
    public double bm25Weight() { return bm25Weight; }
    public double tagWeight() { return tagWeight; }
    public double coverageBonus() { return coverageBonus; }
    public int rateLimitPerMinute() { return rateLimitPerMinute; }

    // setters exist for the evaluation, which sweeps weights; production reads the values from configuration
    void setDenseWeight(double v) { this.denseWeight = v; }
    void setFacetWeight(double v) { this.facetWeight = v; }
    void setBm25Weight(double v) { this.bm25Weight = v; }
    void setTagWeight(double v) { this.tagWeight = v; }
    void setCoverageBonus(double v) { this.coverageBonus = v; }
}
