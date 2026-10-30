package com.example.zomato.entity;

import jakarta.persistence.*;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * One phrase as the nightly job judged it on {@code runDate}: rising, steady, a one-day fluke and so on, with the reason.
 * Holds phrases and counts only, never a searcher or a raw query log row.
 */
@Entity
@Table(name = "search_trend", indexes = @Index(name = "idx_search_trend_run", columnList = "run_date, status, area"))
public class SearchTrend {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "run_date", nullable = false)
    private LocalDate runDate;

    @Column(name = "phrase_key", nullable = false, length = 200)
    private String phraseKey;

    /** FUSION, FLAVOR or DISH */
    @Column(name = "kind", nullable = false, length = 8)
    private String kind;

    @Column(name = "label", nullable = false, length = 200)
    private String label;

    /** Comma separated cuisine ids, e.g. "italian,korean". */
    @Column(name = "cuisines", length = 120)
    private String cuisines;

    @Column(name = "status", nullable = false, length = 10)
    private String status;

    @Column(name = "reason", length = 200)
    private String reason;

    @Column(name = "recent_searchers")
    private int recentSearchers;

    @Column(name = "baseline_searchers")
    private int baselineSearchers;

    @Column(name = "growth")
    private double growth;

    @Column(name = "active_days")
    private int activeDays;

    @Column(name = "top_day_share")
    private double topDayShare;

    /** Share of the recent searches for this phrase that no menu could answer. */
    @Column(name = "unmet_share")
    private double unmetShare;

    /** A few of the ways people phrased it, "|" separated. */
    @Column(name = "samples", length = 400)
    private String samples;

    /** Lowercased city the searches came from; null for the trend across everyone. */
    @Column(name = "area", length = 80)
    private String area;

    @Column(name = "computed_at", nullable = false)
    private LocalDateTime computedAt = LocalDateTime.now();

    public Long getId() { return id; }
    public LocalDate getRunDate() { return runDate; }
    public void setRunDate(LocalDate runDate) { this.runDate = runDate; }
    public String getPhraseKey() { return phraseKey; }
    public void setPhraseKey(String phraseKey) { this.phraseKey = phraseKey; }
    public String getKind() { return kind; }
    public void setKind(String kind) { this.kind = kind; }
    public String getLabel() { return label; }
    public void setLabel(String label) { this.label = label; }
    public String getCuisines() { return cuisines; }
    public void setCuisines(String cuisines) { this.cuisines = cuisines; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }
    public int getRecentSearchers() { return recentSearchers; }
    public void setRecentSearchers(int v) { this.recentSearchers = v; }
    public int getBaselineSearchers() { return baselineSearchers; }
    public void setBaselineSearchers(int v) { this.baselineSearchers = v; }
    public double getGrowth() { return growth; }
    public void setGrowth(double growth) { this.growth = growth; }
    public int getActiveDays() { return activeDays; }
    public void setActiveDays(int activeDays) { this.activeDays = activeDays; }
    public double getTopDayShare() { return topDayShare; }
    public void setTopDayShare(double topDayShare) { this.topDayShare = topDayShare; }
    public double getUnmetShare() { return unmetShare; }
    public void setUnmetShare(double unmetShare) { this.unmetShare = unmetShare; }
    public String getSamples() { return samples; }
    public void setSamples(String samples) { this.samples = samples; }
    public String getArea() { return area; }
    public void setArea(String area) { this.area = area; }
    public LocalDateTime getComputedAt() { return computedAt; }
    public void setComputedAt(LocalDateTime computedAt) { this.computedAt = computedAt; }
}
