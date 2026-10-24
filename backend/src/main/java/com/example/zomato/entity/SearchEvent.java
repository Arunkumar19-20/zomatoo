package com.example.zomato.entity;

import jakarta.persistence.*;

import java.time.LocalDateTime;

/**
 * One craving search, kept so we can see what people look for and which cravings no menu serves yet.
 * Deliberately holds no user id, email or IP: {@code sessionKey} is a salted hash that changes every day, so it can
 * count distinct searchers within a day but cannot follow anyone across days. Raw text is deleted after the retention period.
 */
@Entity
@Table(name = "search_event", indexes = {
        @Index(name = "idx_search_event_created", columnList = "created_at"),
        @Index(name = "idx_search_event_public", columnList = "public_id", unique = true),
        @Index(name = "idx_search_event_session", columnList = "session_key, created_at")})
public class SearchEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Opaque id the app echoes back when the customer opens a result. */
    @Column(name = "public_id", nullable = false, length = 36)
    private String publicId;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    @Column(name = "raw_query", length = 200)
    private String rawQuery;

    /** Lowercased, filler removed, filters taken out: the text trends are counted on. */
    @Column(name = "normalized_query", length = 160)
    private String normalizedQuery;

    /** The parts of the craving, e.g. "sweet|spicy". */
    @Column(name = "facets", length = 300)
    private String facets;

    @Column(name = "flavors", length = 120)
    private String flavors;

    @Column(name = "veg_only")
    private boolean vegOnly;

    @Column(name = "max_price")
    private Float maxPrice;

    @Column(name = "mode", length = 8)
    private String mode;

    /** City-level area the customer reported, if any. */
    @Column(name = "area", length = 80)
    private String area;

    @Column(name = "session_key", length = 16)
    private String sessionKey;

    @Column(name = "requested_k")
    private int requestedK;

    @Column(name = "total_matches")
    private int totalMatches;

    @Column(name = "relevant_count")
    private int relevantCount;

    @Column(name = "bm25_candidates")
    private int bm25Candidates;

    @Column(name = "best_similarity")
    private Double bestSimilarity;

    @Column(name = "top_coverage")
    private Double topCoverage;

    @Column(name = "owner_covered_top3")
    private int ownerCoveredTop3;

    /** The craving looked unserved: see UnmetClassifier for the rule. */
    @Column(name = "unmet")
    private boolean unmet;

    @Column(name = "unmet_basis", length = 48)
    private String unmetBasis;

    /** The same customer kept typing: this partial query was replaced by a longer one and must not be counted. */
    @Column(name = "superseded")
    private boolean superseded;

    /** Item ids of the top results shown, comma separated; a click is only accepted for one of these. */
    @Column(name = "shown_item_ids", length = 300)
    private String shownItemIds;

    @Column(name = "took_ms")
    private int tookMs;

    public Long getId() { return id; }
    public String getPublicId() { return publicId; }
    public void setPublicId(String publicId) { this.publicId = publicId; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    public String getRawQuery() { return rawQuery; }
    public void setRawQuery(String rawQuery) { this.rawQuery = rawQuery; }
    public String getNormalizedQuery() { return normalizedQuery; }
    public void setNormalizedQuery(String normalizedQuery) { this.normalizedQuery = normalizedQuery; }
    public String getFacets() { return facets; }
    public void setFacets(String facets) { this.facets = facets; }
    public String getFlavors() { return flavors; }
    public void setFlavors(String flavors) { this.flavors = flavors; }
    public boolean isVegOnly() { return vegOnly; }
    public void setVegOnly(boolean vegOnly) { this.vegOnly = vegOnly; }
    public Float getMaxPrice() { return maxPrice; }
    public void setMaxPrice(Float maxPrice) { this.maxPrice = maxPrice; }
    public String getMode() { return mode; }
    public void setMode(String mode) { this.mode = mode; }
    public String getArea() { return area; }
    public void setArea(String area) { this.area = area; }
    public String getSessionKey() { return sessionKey; }
    public void setSessionKey(String sessionKey) { this.sessionKey = sessionKey; }
    public int getRequestedK() { return requestedK; }
    public void setRequestedK(int requestedK) { this.requestedK = requestedK; }
    public int getTotalMatches() { return totalMatches; }
    public void setTotalMatches(int totalMatches) { this.totalMatches = totalMatches; }
    public int getRelevantCount() { return relevantCount; }
    public void setRelevantCount(int relevantCount) { this.relevantCount = relevantCount; }
    public int getBm25Candidates() { return bm25Candidates; }
    public void setBm25Candidates(int bm25Candidates) { this.bm25Candidates = bm25Candidates; }
    public Double getBestSimilarity() { return bestSimilarity; }
    public void setBestSimilarity(Double bestSimilarity) { this.bestSimilarity = bestSimilarity; }
    public Double getTopCoverage() { return topCoverage; }
    public void setTopCoverage(Double topCoverage) { this.topCoverage = topCoverage; }
    public int getOwnerCoveredTop3() { return ownerCoveredTop3; }
    public void setOwnerCoveredTop3(int ownerCoveredTop3) { this.ownerCoveredTop3 = ownerCoveredTop3; }
    public boolean isUnmet() { return unmet; }
    public void setUnmet(boolean unmet) { this.unmet = unmet; }
    public String getUnmetBasis() { return unmetBasis; }
    public void setUnmetBasis(String unmetBasis) { this.unmetBasis = unmetBasis; }
    public boolean isSuperseded() { return superseded; }
    public void setSuperseded(boolean superseded) { this.superseded = superseded; }
    public String getShownItemIds() { return shownItemIds; }
    public void setShownItemIds(String shownItemIds) { this.shownItemIds = shownItemIds; }
    public int getTookMs() { return tookMs; }
    public void setTookMs(int tookMs) { this.tookMs = tookMs; }
}
