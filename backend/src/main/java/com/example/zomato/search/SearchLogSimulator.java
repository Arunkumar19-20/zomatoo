package com.example.zomato.search;

import com.example.zomato.entity.SearchAttributionDaily;
import com.example.zomato.entity.SearchClick;
import com.example.zomato.entity.SearchEvent;
import com.example.zomato.repository.SearchAttributionDailyRepository;
import com.example.zomato.repository.SearchClickRepository;
import com.example.zomato.repository.SearchEventRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.UUID;
import java.util.function.IntUnaryOperator;
import java.util.stream.Collectors;

/**
 * Fake search traffic for demos and tests, with known answers planted in it: a Korean x Italian fusion that really takes off, a second
 * dish on the rise, a one-day fluke, a tiny phrase, one device hammering a query, mood searches, steady favourites and a long tail.
 * Every distinct query goes through the real search, so the answer-quality verdicts are genuine; only the people and the clock are made up.
 * Rows are flagged {@code simulated} and are ignored by the trend job unless {@code search.sim.enabled} is on.
 */
@Service
public class SearchLogSimulator {

    public record Scenario(String name, String expected, List<String> queries, IntUnaryOperator searchersOnDay, boolean oneDevice) {}

    public record Report(int days, int searches, int searchers, List<String> scenarios) {}

    private static final int[] FUSION_RAMP = {28, 24, 20, 16, 13, 10, 8, 6, 4, 3, 2, 1};   // daysAgo 0..11
    private static final int[] BIRRIA_RAMP = {9, 8, 6, 5, 4, 3, 2, 1};                     // daysAgo 0..7

    private static final List<String> LONG_TAIL = List.of("paneer tikka", "tiramisu", "pad thai", "dumplings", "brownie", "wings", "tacos", "noodle soup",
            "grilled chicken", "ice cream", "butter chicken", "margherita pizza", "street food chaat", "falafel wrap", "fish curry", "mushroom risotto",
            "chocolate lava cake", "masala dosa", "chicken shawarma", "sushi", "veg thali", "cheesecake", "pho", "sandwich", "momos", "cold coffee",
            "mango lassi", "garlic bread", "fried rice", "chole bhature");

    private final HybridSearchService search;
    private final SearchEventRepository events;
    private final SearchClickRepository clicks;
    private final SearchAttributionDailyRepository attribution;
    private final SearchIndexService index;

    public SearchLogSimulator(HybridSearchService search, SearchEventRepository events, SearchClickRepository clicks, SearchAttributionDailyRepository attribution, SearchIndexService index) {
        this.attribution = attribution;
        this.index = index;
        this.search = search;
        this.events = events;
        this.clicks = clicks;
            }

    public static List<Scenario> scenarios() {
        List<Scenario> s = new ArrayList<>();
        s.add(new Scenario("steady favourites", "STEADY",
                List.of("pizza", "biryani", "burger", "ramen", "sweet and spicy", "creamy and comforting"), d -> 40, false));
        s.add(new Scenario("planted: Korean x Italian fusion", "RISING",
                List.of("korean italian fusion", "kimchi carbonara", "bulgogi pizza", "korean style carbonara", "italian korean fusion pasta", "gochujang pizza"),
                d -> d < FUSION_RAMP.length ? FUSION_RAMP[d] : 0, false));
        s.add(new Scenario("planted: birria tacos, worded several ways", "RISING",
                List.of("birria tacos", "birria taco", "cheesy birria tacos", "taco birria"), d -> d < BIRRIA_RAMP.length ? BIRRIA_RAMP[d] : 0, false));
        s.add(new Scenario("planted: one-day fluke", "FLUKE", List.of("dubai chocolate"), d -> d == 3 ? 45 : 0, false));
        s.add(new Scenario("planted: too few people", "TOO_SMALL", List.of("ethiopian injera"), d -> d < 5 ? 1 : 0, false));
        s.add(new Scenario("planted: one device repeating itself", "TOO_SMALL", List.of("free biryani"), d -> d < 7 ? 60 : 0, true));
        s.add(new Scenario("mood searches, steady", "NONE", List.of("late night snack"), d -> 4, false));
        s.add(new Scenario("mood searches, rising", "NONE", List.of("something to share with friends"), d -> d < 8 ? 9 - d : 0, false));
        s.add(new Scenario("long tail", "TOO_SMALL", LONG_TAIL, d -> 2, false));
        return s;
    }

    @Transactional
    public Report generate(int days, long seed) {
        clear();
        Random rnd = new Random(seed);
        LocalDate today = LocalDate.now();
        Map<String, HybridSearchService.Result> answers = new HashMap<>();
        List<SearchEvent> batch = new ArrayList<>();
        int searchers = 0;

        for (Scenario sc : scenarios()) {
            for (int daysAgo = 0; daysAgo < days; daysAgo++) {
                LocalDate day = today.minusDays(daysAgo);
                int n = sc.searchersOnDay().applyAsInt(daysAgo);
                if (n <= 0) continue;
                if (sc.oneDevice()) {
                    String session = sessionKey(sc.name(), day, 0);
                    searchers++;
                    for (int i = 0; i < n; i++) batch.add(event(sc, pick(sc, rnd), day, session, rnd, answers));
                    continue;
                }
                int actual = Math.max(1, (int) Math.round(n * (0.85 + rnd.nextDouble() * 0.3)));
                for (int j = 0; j < actual; j++) {
                    String session = sessionKey(sc.name(), day, j);
                    searchers++;
                    batch.add(event(sc, pick(sc, rnd), day, session, rnd, answers));
                }
            }
        }
        events.saveAll(batch);
        // about one search in five ends in a tap on the first result (more for the dish people really want)
        Map<String, String> scenarioOf = new HashMap<>();
        scenarios().forEach(sc -> sc.queries().forEach(q -> scenarioOf.put(q, sc.name())));
        List<SearchClick> taps = new ArrayList<>();
        for (SearchEvent e : batch) {
            if (e.getShownItemIds() == null || e.getShownItemIds().isBlank() || rnd.nextDouble() > TAP_RATE.getOrDefault(scenarioOf.get(e.getRawQuery()), DEFAULT_TAP_RATE)) continue;
            taps.add(new SearchClick(e.getId(), Integer.parseInt(e.getShownItemIds().split(",")[0]), 1, SearchClick.OPEN));
        }
        clicks.saveAll(taps);
        saveOrders(batch, taps, rnd);
        return new Report(days, batch.size(), searchers, scenarios().stream().map(Scenario::name).collect(Collectors.toList()));
    }

    /** Share of searches that end in a tap on the first result. */
    private static final Map<String, Double> TAP_RATE = Map.of("planted: birria tacos, worded several ways", 0.45);
    private static final double DEFAULT_TAP_RATE = 0.2;

    /** Share of tapped results that end in a delivered order, by scenario. Birria is the dish people really want. */
    private static final Map<String, Double> ORDER_RATE = Map.of("planted: birria tacos, worded several ways", 0.6, "steady favourites", 0.22);
    private static final double DEFAULT_ORDER_RATE = 0.12;

    /** Delivered orders from taps, as the daily counts the real flow produces (no order or customer ids exist for simulated ones either). */
    private void saveOrders(List<SearchEvent> events, List<SearchClick> taps, Random rnd) {
        Map<Long, SearchEvent> byId = new HashMap<>();
        events.forEach(e -> byId.put(e.getId(), e));
        Map<String, String> scenarioOf = new HashMap<>();
        scenarios().forEach(sc -> sc.queries().forEach(q -> scenarioOf.put(q, sc.name())));
        Map<String, SearchAttributionDaily> rows = new HashMap<>();
        for (SearchClick tap : taps) {
            SearchEvent e = byId.get(tap.getSearchEventId());
            PhraseMiner.Phrase phrase = PhraseMiner.mine(e.getNormalizedQuery(), e.getFlavors());
            var dish = index.doc(tap.getItemId());
            if (phrase == null || dish.isEmpty()) continue;
            if (rnd.nextDouble() > ORDER_RATE.getOrDefault(scenarioOf.get(e.getRawQuery()), DEFAULT_ORDER_RATE)) continue;
            int qty = 1 + rnd.nextInt(2);
            var day = e.getCreatedAt().toLocalDate();
            String k = day + "|" + phrase.key() + "|" + tap.getItemId();
            rows.computeIfAbsent(k, x -> new SearchAttributionDaily(day, phrase.key(), dish.get().restaurantId(), tap.getItemId(), true)).add(1, qty, qty * (double) dish.get().price());
        }
        attribution.saveAll(rows.values());
    }

    /** Removes everything this simulator made. */
    @Transactional
    public int clear() {
        attribution.deleteSimulated();
        events.deleteSimulatedClicks();
        return events.deleteSimulated();
    }

    private static String pick(Scenario sc, Random rnd) { return sc.queries().get(rnd.nextInt(sc.queries().size())); }

    private SearchEvent event(Scenario sc, String query, LocalDate day, String session, Random rnd, Map<String, HybridSearchService.Result> answers) {
        HybridSearchService.Result r = answers.computeIfAbsent(query, q -> search.search(new HybridSearchService.Request(q, 10, null, null, false)));
        HybridSearchService.Diagnostics d = r.diagnostics();
        UnmetClassifier.Verdict v = UnmetClassifier.judge(r.parsed(), d, "HYBRID".equals(r.mode()));
        SearchEvent e = new SearchEvent();
        e.setPublicId(UUID.randomUUID().toString());
        e.setCreatedAt(day.atTime(9 + rnd.nextInt(14), rnd.nextInt(60), rnd.nextInt(60)));
        e.setRawQuery(query);
        e.setNormalizedQuery(SearchEventService.normalize(r));
        e.setFacets(r.parsed().facets().stream().map(f -> f.text()).collect(Collectors.joining("|")));
        e.setFlavors(r.parsed().flavors().stream().map(Flavor::id).sorted().collect(Collectors.joining(",")));
        e.setVegOnly(r.parsed().vegOnly());
        e.setMaxPrice(r.parsed().maxPrice());
        e.setMode(r.mode());
        e.setSessionKey(session);
        e.setRequestedK(10);
        e.setTotalMatches(r.total());
        e.setRelevantCount(d.relevantCount());
        e.setBm25Candidates(d.bm25Candidates());
        e.setBestSimilarity(d.bestSimilarity());
        e.setTopCoverage(d.topCoverage());
        e.setOwnerCoveredTop3(d.ownerCoveredTop3());
        e.setUnmet(v.unmet());
        e.setUnmetBasis(v.basis());
        e.setShownItemIds(r.hits().stream().map(h -> String.valueOf(h.doc().itemId())).collect(Collectors.joining(",")));
        e.setTookMs((int) r.tookMs());
        e.setSimulated(true);
        return e;
    }

    private static String sessionKey(String scenario, LocalDate day, int index) {
        try {
            byte[] h = MessageDigest.getInstance("SHA-256").digest(("sim|" + scenario + "|" + day + "|" + index).getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < 8; i++) sb.append(String.format("%02x", h[i]));
            return sb.toString();
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException(ex);
        }
    }
}
