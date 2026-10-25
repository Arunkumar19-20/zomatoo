package com.example.zomato.entity;

import jakarta.persistence.*;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Something we suggest a restaurant do about a rising craving: add a dish, keep more of one it has, or make it a Drop.
 * Holds the phrase and the counts behind it, never a searcher or a raw query.
 */
@Entity
@Table(name = "owner_suggestion", indexes = {
        @Index(name = "idx_owner_suggestion_rest", columnList = "restaurant_id, trend_key"),
        @Index(name = "idx_owner_suggestion_status", columnList = "status, score")})
public class OwnerSuggestion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "restaurant_id", nullable = false)
    private int restaurantId;

    /** The restaurant's owner, when it has one: the weekly limit is per owner, not per restaurant. */
    @Column(name = "owner_id")
    private Integer ownerId;

    @Column(name = "trend_key", nullable = false, length = 200)
    private String trendKey;

    @Column(name = "trend_label", nullable = false, length = 200)
    private String trendLabel;

    /** ADD_DISH, STOCK_UP or MAKE_DROP */
    @Column(name = "type", nullable = false, length = 10)
    private String type;

    /** NEW, DISMISSED, SNOOZED, ACTED or EXPIRED */
    @Column(name = "status", nullable = false, length = 10)
    private String status = "NEW";

    @Column(name = "snoozed_until")
    private LocalDate snoozedUntil;

    /** Monday of the week it was created, for the weekly limit. */
    @Column(name = "week_start", nullable = false)
    private LocalDate weekStart;

    @Column(name = "run_date", nullable = false)
    private LocalDate runDate;

    @Column(name = "score")
    private double score;

    @Column(name = "headline", length = 300)
    private String headline;

    @Column(name = "body", length = 1200)
    private String body;

    /** JSON: the prefilled add-dish or drop form and the evidence (see SuggestionService.Payload). */
    @Column(name = "payload", length = 4000)
    private String payload;

    @Column(name = "recent_searchers")
    private int recentSearchers;

    @Column(name = "baseline_searchers")
    private int baselineSearchers;

    @Column(name = "growth")
    private double growth;

    @Column(name = "unmet_share")
    private double unmetShare;

    /** Recent searches for the phrase that showed one of this restaurant's dishes, and how many were tapped. */
    @Column(name = "impressions")
    private int impressions;

    @Column(name = "taps")
    private int taps;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt = LocalDateTime.now();

    public Long getId() { return id; }
    public int getRestaurantId() { return restaurantId; }
    public void setRestaurantId(int v) { this.restaurantId = v; }
    public Integer getOwnerId() { return ownerId; }
    public void setOwnerId(Integer v) { this.ownerId = v; }
    public String getTrendKey() { return trendKey; }
    public void setTrendKey(String v) { this.trendKey = v; }
    public String getTrendLabel() { return trendLabel; }
    public void setTrendLabel(String v) { this.trendLabel = v; }
    public String getType() { return type; }
    public void setType(String v) { this.type = v; }
    public String getStatus() { return status; }
    public void setStatus(String v) { this.status = v; }
    public LocalDate getSnoozedUntil() { return snoozedUntil; }
    public void setSnoozedUntil(LocalDate v) { this.snoozedUntil = v; }
    public LocalDate getWeekStart() { return weekStart; }
    public void setWeekStart(LocalDate v) { this.weekStart = v; }
    public LocalDate getRunDate() { return runDate; }
    public void setRunDate(LocalDate v) { this.runDate = v; }
    public double getScore() { return score; }
    public void setScore(double v) { this.score = v; }
    public String getHeadline() { return headline; }
    public void setHeadline(String v) { this.headline = v; }
    public String getBody() { return body; }
    public void setBody(String v) { this.body = v; }
    public String getPayload() { return payload; }
    public void setPayload(String v) { this.payload = v; }
    public int getRecentSearchers() { return recentSearchers; }
    public void setRecentSearchers(int v) { this.recentSearchers = v; }
    public int getBaselineSearchers() { return baselineSearchers; }
    public void setBaselineSearchers(int v) { this.baselineSearchers = v; }
    public double getGrowth() { return growth; }
    public void setGrowth(double v) { this.growth = v; }
    public double getUnmetShare() { return unmetShare; }
    public void setUnmetShare(double v) { this.unmetShare = v; }
    public int getImpressions() { return impressions; }
    public void setImpressions(int v) { this.impressions = v; }
    public int getTaps() { return taps; }
    public void setTaps(int v) { this.taps = v; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime v) { this.createdAt = v; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime v) { this.updatedAt = v; }
}
