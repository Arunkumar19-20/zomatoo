package com.example.zomato.search;

import com.example.zomato.entity.SearchTrend;
import com.example.zomato.repository.SearchEventRepository;
import com.example.zomato.repository.SearchTrendRepository;
import com.example.zomato.search.PhraseMiner.Kind;
import com.example.zomato.search.PhraseMiner.Phrase;
import com.example.zomato.search.TrendDetector.Series;
import com.example.zomato.search.TrendDetector.Status;
import com.example.zomato.search.TrendDetector.Trend;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.EnumMap;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.stream.Collectors;

/**
 * The nightly trend job: reads the last five weeks of finished searches, turns each into a phrase, combines different wordings
 * of the same demand (stemming, word order, spelling variants; see PhraseMiner), and records which phrases are rising. Counts people (searchers per day), not searches.
 */
@Service
public class TrendService {

    private static final Logger log = LoggerFactory.getLogger(TrendService.class);
    private static final int KEEP_DAYS = 30;

    private final SearchEventRepository events;
    private final SearchTrendRepository trends;
    private final SearchProperties props;

    public TrendService(SearchEventRepository events, SearchTrendRepository trends, SearchProperties props) {
        this.events = events;
        this.trends = trends;
        this.props = props;
    }

    public record RunSummary(LocalDate asOf, int searchesRead, int searchesWithoutPhrase, int phrases, int wordingsCombined, Map<String, Integer> byStatus,
                             int areas, int areasWithTrends) {}

    public record TrendView(LocalDate runDate, String status, String kind, String label, String key, List<String> cuisines, String reason,
                            int recentSearchers, int baselineSearchers, double growth, int activeDays, double topDayShare, double unmetShare,
                            List<String> samples, String area) {

        public TrendView(LocalDate runDate, String status, String kind, String label, String key, List<String> cuisines, String reason,
                         int recentSearchers, int baselineSearchers, double growth, int activeDays, double topDayShare, double unmetShare, List<String> samples) {
            this(runDate, status, kind, label, key, cuisines, reason, recentSearchers, baselineSearchers, growth, activeDays, topDayShare, unmetShare, samples, null);
        }
    }

    private static final class Acc {
        Phrase phrase;
        final Map<LocalDate, Set<String>> searchers = new TreeMap<>();
        final Map<String, Integer> forms = new HashMap<>();
        int recentSearches, recentUnmet;

        Acc(Phrase p) { this.phrase = p; }

        int searcherDays() { return searchers.values().stream().mapToInt(Set::size).sum(); }

        String topForm() {
            return forms.entrySet().stream().max(Map.Entry.<String, Integer>comparingByValue().thenComparing(Map.Entry.comparingByKey())).map(Map.Entry::getKey).orElse("");
        }

        void absorb(Acc o) {
            o.searchers.forEach((d, set) -> searchers.computeIfAbsent(d, k -> new HashSet<>()).addAll(set));
            o.forms.forEach((f, n) -> forms.merge(f, n, Integer::sum));
            recentSearches += o.recentSearches;
            recentUnmet += o.recentUnmet;
        }
    }

    private record Assessed(List<SearchTrend> rows, EnumMap<Status, Integer> counts, int read, int skipped, int phrases, int combined) {}

    @Transactional
    public RunSummary run(LocalDate asOf) {
        TrendDetector.Params params = props.trendParams();
        LocalDate recentFrom = asOf.minusDays(params.recentDays() - 1L);
        LocalDateTime since = recentFrom.minusDays(params.baselineDays()).atStartOfDay();
        List<Object[]> rows = events.trendInputsSince(since, props.simEnabled());
        LocalDateTime now = LocalDateTime.now();

        Assessed global = assess(rows, asOf, params, null, now);
        List<SearchTrend> out = new ArrayList<>(global.rows());

        // the same judgement over each area's own searches; an area only gets rows once enough of its own people searched the phrase
        Map<String, List<Object[]>> byArea = new TreeMap<>();
        for (Object[] r : rows) {
            String area = r.length > 5 ? (String) r[5] : null;
            if (area != null && !area.isBlank()) byArea.computeIfAbsent(area, k -> new ArrayList<>()).add(r);
        }
        int areasWithTrends = 0;
        for (Map.Entry<String, List<Object[]>> e : byArea.entrySet()) {
            List<SearchTrend> areaRows = assess(e.getValue(), asOf, params, e.getKey(), now).rows();
            if (!areaRows.isEmpty()) areasWithTrends++;
            out.addAll(areaRows);
        }

        trends.deleteByDay(asOf);
        trends.saveAll(out);
        trends.deleteOlderThan(asOf.minusDays(KEEP_DAYS));

        Map<String, Integer> byStatus = new LinkedHashMap<>();
        for (Status st : Status.values()) byStatus.put(st.name(), global.counts().getOrDefault(st, 0));
        return new RunSummary(asOf, global.read(), global.skipped(), global.phrases(), global.combined(), byStatus, byArea.size(), areasWithTrends);
    }

    /** Judges every phrase in {@code rows} (all searches, or one area's) and returns the rows worth keeping; {@code area} null means everyone. */
    private Assessed assess(List<Object[]> rows, LocalDate asOf, TrendDetector.Params params, String area, LocalDateTime now) {
        LocalDate recentFrom = asOf.minusDays(params.recentDays() - 1L);
        Map<String, Acc> byKey = new LinkedHashMap<>();
        Map<String, Phrase> mined = new HashMap<>();
        int read = 0, skipped = 0;
        for (Object[] r : rows) {
            LocalDateTime at = (LocalDateTime) r[0];
            LocalDate day = at.toLocalDate();
            if (day.isAfter(asOf)) continue;
            read++;
            String normalized = (String) r[1];
            String flavors = (String) r[2];
            boolean unmet = Boolean.TRUE.equals(r[3]);
            String session = (String) r[4];
            Phrase p = mined.computeIfAbsent(normalized + "\u0001" + flavors, k -> PhraseMiner.mine(normalized, flavors));
            if (p == null) {
                skipped++;
                continue;
            }
            Acc a = byKey.computeIfAbsent(p.key(), k -> new Acc(p));
            a.searchers.computeIfAbsent(day, k -> new HashSet<>()).add(session == null ? "?" : session);
            a.forms.merge(normalized, 1, Integer::sum);
            if (!day.isBefore(recentFrom)) {
                a.recentSearches++;
                if (unmet) a.recentUnmet++;
            }
        }

        int distinctForms = (int) byKey.values().stream().mapToLong(a -> a.forms.size()).sum();
        int combined = Math.max(0, distinctForms - byKey.size());

        EnumMap<Status, Integer> counts = new EnumMap<>(Status.class);
        List<SearchTrend> out = new ArrayList<>();
        for (Acc a : byKey.values()) {
            Series s = new Series(a.phrase.key(), a.phrase.kind(), label(a), a.phrase.cuisines(),
                    a.searchers.entrySet().stream().collect(Collectors.toMap(Map.Entry::getKey, e -> e.getValue().size())),
                    a.recentSearches, a.recentUnmet, topForms(a, 4));
            Trend t = TrendDetector.assess(s, asOf, params);
            counts.merge(t.status(), 1, Integer::sum);
            if (t.status() != Status.TOO_SMALL) {
                SearchTrend row = toRow(t, asOf, now);
                row.setArea(area);
                out.add(row);
            }
        }
        return new Assessed(out, counts, read, skipped, byKey.size(), combined);
    }

    private static String label(Acc a) {
        if (a.phrase.kind() != Kind.DISH) return a.phrase.label();
        String top = a.topForm();
        return top.isBlank() ? a.phrase.label() : titleCase(top);
    }

    private static String titleCase(String s) {
        String[] words = s.trim().split("\\s+");
        StringBuilder sb = new StringBuilder();
        for (String w : words) {
            if (sb.length() > 0) sb.append(' ');
            sb.append(w.substring(0, 1).toUpperCase(Locale.ROOT)).append(w.substring(1));
        }
        return sb.toString();
    }

    private static List<String> topForms(Acc a, int n) {
        return a.forms.entrySet().stream().sorted(Map.Entry.<String, Integer>comparingByValue().reversed().thenComparing(Map.Entry.comparingByKey()))
                .limit(n).map(Map.Entry::getKey).toList();
    }

    private static SearchTrend toRow(Trend t, LocalDate asOf, LocalDateTime now) {
        SearchTrend row = new SearchTrend();
        row.setRunDate(asOf);
        row.setPhraseKey(t.series().key());
        row.setKind(t.series().kind().name());
        row.setLabel(t.series().label());
        row.setCuisines(String.join(",", new java.util.TreeSet<>(t.series().cuisines())));
        row.setStatus(t.status().name());
        row.setReason(t.reason());
        row.setRecentSearchers(t.recentSearchers());
        row.setBaselineSearchers(t.baselineSearchers());
        row.setGrowth(Math.round(t.growth() * 100) / 100.0);
        row.setActiveDays(t.activeDays());
        row.setTopDayShare(Math.round(t.topDayShare() * 100) / 100.0);
        row.setUnmetShare(Math.round(t.unmetShare() * 100) / 100.0);
        String samples = String.join("|", t.series().samples());
        row.setSamples(samples.length() > 400 ? samples.substring(0, 400) : samples);
        row.setComputedAt(now);
        return row;
    }

    /** Rising phrases in the snapshot taken on one day. */
    @Transactional(readOnly = true)
    public List<TrendView> rising(LocalDate day) {
        return trends.findByRunDateAndAreaIsNullAndStatusOrderByGrowthDesc(day, Status.RISING.name()).stream().map(TrendService::view).toList();
    }

    /** The latest snapshot across everyone, optionally one status only (for example RISING). */
    @Transactional(readOnly = true)
    public List<TrendView> latest(String status) {
        return latest(status, null);
    }

    /** The latest snapshot among searches from one area (null or blank: across everyone). Areas compare case-insensitively. */
    @Transactional(readOnly = true)
    public List<TrendView> latest(String status, String area) {
        LocalDate day = trends.latestRunDate();
        if (day == null) return List.of();
        String a = normalizeArea(area);
        boolean any = status == null || status.isBlank();
        String st = any ? null : status.trim().toUpperCase(Locale.ROOT);
        List<SearchTrend> rows;
        if (a == null) {
            rows = any ? trends.findByRunDateAndAreaIsNullOrderByRecentSearchersDesc(day) : trends.findByRunDateAndAreaIsNullAndStatusOrderByGrowthDesc(day, st);
        } else {
            rows = any ? trends.findByRunDateAndAreaOrderByRecentSearchersDesc(day, a) : trends.findByRunDateAndAreaAndStatusOrderByGrowthDesc(day, a, st);
        }
        return rows.stream().map(TrendService::view).toList();
    }

    /** The form areas are stored in: trimmed and lowercase; blank means none. */
    public static String normalizeArea(String area) {
        if (area == null || area.isBlank()) return null;
        String a = area.trim().toLowerCase(Locale.ROOT);
        return a.length() > 80 ? a.substring(0, 80) : a;
    }

    static TrendView view(SearchTrend t) {
        return new TrendView(t.getRunDate(), t.getStatus(), t.getKind(), t.getLabel(), t.getPhraseKey(),
                t.getCuisines() == null || t.getCuisines().isBlank() ? List.of() : List.of(t.getCuisines().split(",")), t.getReason(),
                t.getRecentSearchers(), t.getBaselineSearchers(), t.getGrowth(), t.getActiveDays(), t.getTopDayShare(), t.getUnmetShare(),
                t.getSamples() == null || t.getSamples().isBlank() ? List.of() : List.of(t.getSamples().split("\\|")), t.getArea());
    }
}
