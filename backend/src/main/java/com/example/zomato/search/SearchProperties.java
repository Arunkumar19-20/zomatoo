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

    /** A dish this close in meaning to the craving counts as relevant when judging whether a craving is served. */
    @Value("${search.log.unmet-similarity:0.62}")
    private double unmetSimilarity;

    @Value("${search.log.enabled:true}")
    private boolean logEnabled;

    /** Raw search text is deleted after this many days; the aggregates built from it stay. */
    @Value("${search.log.retention-days:90}")
    private int logRetentionDays;

    /** Secret mixed into the anonymous session key; set SEARCH_LOG_SECRET in production. */
    @Value("${search.log.session-secret:dev-only-change-me}")
    private String logSessionSecret;

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
    public double unmetSimilarity() { return unmetSimilarity; }
    public boolean logEnabled() { return logEnabled; }
    public int logRetentionDays() { return logRetentionDays; }
    public String logSessionSecret() { return logSessionSecret; }
    void setUnmetSimilarity(double v) { this.unmetSimilarity = v; }
    void setLogEnabled(boolean v) { this.logEnabled = v; }

    // setters exist for the evaluation, which sweeps weights; production reads the values from configuration
    void setDenseWeight(double v) { this.denseWeight = v; }
    void setFacetWeight(double v) { this.facetWeight = v; }
    void setBm25Weight(double v) { this.bm25Weight = v; }
    void setTagWeight(double v) { this.tagWeight = v; }
    void setCoverageBonus(double v) { this.coverageBonus = v; }
}
