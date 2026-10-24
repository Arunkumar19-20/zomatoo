package com.example.zomato.search;

import com.example.zomato.entity.SearchClick;
import com.example.zomato.entity.SearchEvent;
import com.example.zomato.repository.SearchClickRepository;
import com.example.zomato.repository.SearchEventRepository;
import com.example.zomato.search.HybridSearchService.Diagnostics;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Records what people search for, without recording who. See SearchEvent for what is and is not kept.
 * Every method that writes is safe to fail: callers wrap it so a logging problem can never break a search.
 */
@Service
public class SearchEventService {

    private static final Logger log = LoggerFactory.getLogger(SearchEventService.class);
    private static final Duration TYPING_WINDOW = Duration.ofSeconds(20);
    private static final Duration CLICK_WINDOW = Duration.ofHours(6);
    private static final Set<String> ACTIONS = Set.of(SearchClick.OPEN, SearchClick.ADD_TO_CART);

    private final SearchEventRepository events;
    private final SearchClickRepository clicks;
    private final SearchProperties props;

    public SearchEventService(SearchEventRepository events, SearchClickRepository clicks, SearchProperties props) {
        this.events = events;
        this.clicks = clicks;
        this.props = props;
    }

    /** What we know about the caller, none of which is stored as is. */
    public record Context(String clientId, String ip, String area, boolean doNotTrack) {}

    public record ClickResult(boolean accepted, String reason) {}

    /** @return the public id to hand back to the app, or empty when nothing was logged (disabled, do-not-track, empty query) */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public Optional<String> record(String rawQuery, HybridSearchService.Result r, int requestedK, Context ctx) {
        if (!props.logEnabled() || ctx.doNotTrack() || rawQuery == null || rawQuery.isBlank()) return Optional.empty();

        String normalized = clip(normalize(r), 160);
        String session = sessionKey(ctx, LocalDate.now(ZoneOffset.UTC));
        LocalDateTime now = LocalDateTime.now();

        // typing "sweet", pausing, then "sweet but also spicy" must count once: retire the shorter, earlier query
        events.findFirstBySessionKeyAndSupersededFalseOrderByCreatedAtDesc(session)
                .filter(prev -> Duration.between(prev.getCreatedAt(), now).compareTo(TYPING_WINDOW) <= 0)
                .filter(prev -> normalized.length() > prev.getNormalizedQuery().length() && normalized.startsWith(prev.getNormalizedQuery()))
                .ifPresent(prev -> {
                    prev.setSuperseded(true);
                    events.save(prev);
                });

        Diagnostics d = r.diagnostics();
        UnmetClassifier.Verdict verdict = UnmetClassifier.judge(r.parsed(), d, "HYBRID".equals(r.mode()));

        SearchEvent e = new SearchEvent();
        e.setPublicId(UUID.randomUUID().toString());
        e.setCreatedAt(now);
        e.setRawQuery(clip(rawQuery.trim(), 200));
        e.setNormalizedQuery(normalized);
        e.setFacets(clip(r.parsed().facets().stream().map(f -> f.text()).collect(Collectors.joining("|")), 300));
        e.setFlavors(clip(r.parsed().flavors().stream().map(Flavor::id).sorted().collect(Collectors.joining(",")), 120));
        e.setVegOnly(r.parsed().vegOnly());
        e.setMaxPrice(r.parsed().maxPrice());
        e.setMode(r.mode());
        e.setArea(ctx.area() == null || ctx.area().isBlank() ? null : clip(ctx.area().trim().toLowerCase(), 80));
        e.setSessionKey(session);
        e.setRequestedK(requestedK);
        e.setTotalMatches(r.total());
        e.setRelevantCount(d.relevantCount());
        e.setBm25Candidates(d.bm25Candidates());
        e.setBestSimilarity(d.bestSimilarity());
        e.setTopCoverage(d.topCoverage());
        e.setOwnerCoveredTop3(d.ownerCoveredTop3());
        e.setUnmet(verdict.unmet());
        e.setUnmetBasis(verdict.basis());
        e.setShownItemIds(r.hits().stream().map(h -> String.valueOf(h.doc().itemId())).collect(Collectors.joining(",")));
        e.setTookMs((int) r.tookMs());
        events.save(e);
        return Optional.of(e.getPublicId());
    }

    /** A customer opened or added a dish from a search. Accepted only for a dish that search actually showed, from the same searcher. */
    @Transactional
    public ClickResult recordClick(String publicId, int itemId, int rank, String action, Context ctx) {
        if (!props.logEnabled() || ctx.doNotTrack()) return new ClickResult(false, "logging-off");
        String act = action == null ? SearchClick.OPEN : action.trim().toUpperCase();
        if (!ACTIONS.contains(act)) return new ClickResult(false, "bad-action");
        Optional<SearchEvent> found = events.findByPublicId(publicId == null ? "" : publicId);
        if (found.isEmpty()) return new ClickResult(false, "unknown-search");
        SearchEvent e = found.get();
        if (Duration.between(e.getCreatedAt(), LocalDateTime.now()).compareTo(CLICK_WINDOW) > 0) return new ClickResult(false, "too-old");
        if (!e.getSessionKey().equals(sessionKey(ctx, e.getCreatedAt().toLocalDate()))) return new ClickResult(false, "different-searcher");
        List<String> shown = e.getShownItemIds() == null ? List.of() : List.of(e.getShownItemIds().split(","));
        if (!shown.contains(String.valueOf(itemId))) return new ClickResult(false, "not-shown");
        if (clicks.existsBySearchEventIdAndItemIdAndAction(e.getId(), itemId, act)) return new ClickResult(true, "duplicate");
        clicks.save(new SearchClick(e.getId(), itemId, Math.max(1, rank), act));
        return new ClickResult(true, "ok");
    }

    /**
     * Anonymous, day-scoped searcher key: HMAC of (UTC date, client id or IP) with a server secret, shortened. The same
     * person gets a different key tomorrow, so keys count distinct searchers per day and cannot be joined across days.
     */
    String sessionKey(Context ctx, LocalDate day) {
        String who = ctx.clientId() != null && !ctx.clientId().isBlank() ? "c:" + ctx.clientId().trim() : "ip:" + (ctx.ip() == null ? "?" : ctx.ip());
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(props.logSessionSecret().getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] h = mac.doFinal((day + "|" + who).getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < 8; i++) sb.append(String.format("%02x", h[i]));
            return sb.toString();
        } catch (java.security.GeneralSecurityException ex) {
            throw new IllegalStateException(ex);
        }
    }

    /** Lowercase, filler and filters removed (what the parser leaves), so "I want something sweet" and "sweet" are one demand. */
    static String normalize(HybridSearchService.Result r) {
        String n = r.parsed().normalized();
        return (n == null || n.isBlank() ? r.parsed().original() : n).toLowerCase().replaceAll("\\s+", " ").trim();
    }

    private static String clip(String s, int max) { return s == null ? null : s.length() <= max ? s : s.substring(0, max); }

    // ------------------------------------------------------------------ retention and summary

    /** Deletes raw search text (and its clicks) older than the retention period. */
    @Transactional
    public int purgeOld() {
        LocalDateTime cutoff = LocalDateTime.now().minusDays(props.logRetentionDays());
        events.deleteClicksOlderThan(cutoff);
        int n = events.deleteOlderThan(cutoff);
        if (n > 0) log.info("Search log: deleted {} searches older than {} days", n, props.logRetentionDays());
        return n;
    }

    @Scheduled(cron = "${search.log.purge-cron:0 30 3 * * *}")
    public void nightlyPurge() {
        try {
            purgeOld();
        } catch (RuntimeException e) {
            log.error("Search log purge failed: {}", e.getMessage(), e);
        }
    }

    public record QueryRow(String query, long searches, long unmet, long searchers) {}

    public record Summary(int days, long searches, long searchers, long unmet, double unmetShare, long searchesWithClick, double clickRate,
                          List<QueryRow> topQueries) {}

    @Transactional(readOnly = true)
    public Summary summary(int days, int top) {
        LocalDateTime since = LocalDateTime.now().minusDays(Math.max(1, days));
        long total = events.countSince(since);
        long unmet = events.countUnmetSince(since);
        long withClick = events.countSearchesWithClickSince(since);
        List<QueryRow> rows = new ArrayList<>();
        for (Object[] r : events.topQueriesSince(since, PageRequest.of(0, Math.max(1, Math.min(top, 100))))) {
            rows.add(new QueryRow((String) r[0], ((Number) r[1]).longValue(), ((Number) r[2]).longValue(), ((Number) r[3]).longValue()));
        }
        return new Summary(days, total, events.countSessionsSince(since), unmet, total == 0 ? 0 : (double) unmet / total,
                withClick, total == 0 ? 0 : (double) withClick / total, rows);
    }
}
