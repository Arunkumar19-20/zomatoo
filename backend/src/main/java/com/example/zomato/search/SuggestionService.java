package com.example.zomato.search;

import com.example.zomato.entity.OwnerSuggestion;
import com.example.zomato.entity.Restaurant;
import com.example.zomato.repository.OwnerSuggestionRepository;
import com.example.zomato.repository.RestaurantRepository;
import com.example.zomato.repository.SearchEventRepository;
import com.example.zomato.search.PhraseMiner.Kind;
import com.example.zomato.search.TrendMatcher.Fit;
import com.example.zomato.search.TrendMatcher.Match;
import com.example.zomato.search.TrendService.TrendView;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Turns rising phrases into things a restaurant can do, at most three per owner per week:
 * <ul>
 *   <li>ADD_DISH: the phrase is rising, the menu has nothing like it, and the restaurant is a natural place for it. Comes with a prefilled add-dish form.</li>
 *   <li>STOCK_UP: the restaurant already has the dish. Guidance to keep more ready, with how often its dish showed up and was tapped.</li>
 *   <li>MAKE_DROP: the same, for a strongly rising phrase: a limited Drop with a suggested size and window.</li>
 * </ul>
 * There is no sales estimate: searches are not yet tied to orders, so the numbers shown are searchers, impressions and taps, all counted.
 */
@Service
public class SuggestionService {

    private static final Logger log = LoggerFactory.getLogger(SuggestionService.class);

    public static final int WEEKLY_CAP = 3;
    static final int DISMISS_COOLDOWN_DAYS = 30;
    static final int SNOOZE_DAYS = 7;
    static final int DROP_MIN_SEARCHERS = 20;
    static final double DROP_MIN_GROWTH = 3.0;
    /** An estimate needs this much counted history behind it, or it is not shown. */
    static final int ESTIMATE_MIN_ORDERS = 3;
    static final int ESTIMATE_MIN_TAPS = 10;
    static final int ESTIMATE_DAYS = 28;

    public enum Type { ADD_DISH, STOCK_UP, MAKE_DROP }

    public enum Status { NEW, DISMISSED, SNOOZED, ACTED, EXPIRED }

    /** The form to prefill and the evidence behind the suggestion, stored as JSON. */
    public record Payload(String suggestedName, String description, List<String> flavorTags, Integer dishId, String dishName, Double price,
                          Boolean dishAvailable, Integer suggestedSlots, String suggestedStartsAt, String suggestedEndsAt, List<String> exampleSearches,
                          Estimate estimate) {
        Payload withEstimate(Estimate e) {
            return new Payload(suggestedName, description, flavorTags, dishId, dishName, price, dishAvailable, suggestedSlots, suggestedStartsAt, suggestedEndsAt, exampleSearches, e);
        }
    }

    /**
     * What search has actually brought this restaurant, projected one week ahead at the same rate. Only built from counted delivered orders:
     * {@code basis} is PHRASE when this very phrase has enough history, RESTAURANT when it falls back to all of the restaurant's search-driven orders.
     */
    public record Estimate(int weeklyOrders, long weeklyRevenue, long ordersObserved, int tapsObserved, String basis) {}

    public record View(long id, int restaurantId, String restaurantName, String type, String status, String trendKey, String trendLabel, String headline,
                       String body, double score, int recentSearchers, int baselineSearchers, double growth, double unmetShare, int impressions,
                       int taps, Payload payload, LocalDate snoozedUntil, LocalDateTime createdAt) {}

    public record GenerateSummary(LocalDate runDate, int risingTrends, int candidates, int created, int refreshed, int skippedByCap, int skippedByHistory,
                                  int expired, Map<String, Integer> createdByType) {}

    private record Evidence(int impressions, int taps) {}

    private record Candidate(Restaurant restaurant, Integer ownerId, TrendView trend, Match match, Type type, double score, Evidence evidence,
                             Payload payload, String headline, String body) {}

    private final OwnerSuggestionRepository suggestions;
    private final RestaurantRepository restaurants;
    private final SearchEventRepository events;
    private final SearchIndexService index;
    private final TrendService trends;
    private final SearchProperties props;
    private final OrderAttributionService attribution;
    private final ObjectMapper json = new ObjectMapper();

    public SuggestionService(OwnerSuggestionRepository suggestions, RestaurantRepository restaurants, SearchEventRepository events,
                             SearchIndexService index, TrendService trends, SearchProperties props, OrderAttributionService attribution) {
        this.attribution = attribution;
        this.suggestions = suggestions;
        this.restaurants = restaurants;
        this.events = events;
        this.index = index;
        this.trends = trends;
        this.props = props;
    }

    // ------------------------------------------------------------------ generation

    @Transactional
    public GenerateSummary generate(LocalDate runDate) {
        List<TrendView> rising = trends.rising(runDate);
        Map<Integer, List<DishDoc>> menus = index.allDocs().stream().collect(Collectors.groupingBy(DishDoc::restaurantId));
        Map<Integer, Restaurant> byId = restaurants.findAllById(menus.keySet()).stream().collect(Collectors.toMap(Restaurant::getId, r -> r));
        Set<String> keys = rising.stream().map(TrendView::key).collect(Collectors.toSet());
        Counts last7 = countsFor(keys, runDate.minusDays(6).atStartOfDay());
        Counts last28 = countsFor(keys, runDate.minusDays(ESTIMATE_DAYS - 1).atStartOfDay());

        List<Candidate> candidates = new ArrayList<>();
        for (TrendView t : rising) {
            for (var e : menus.entrySet()) {
                Restaurant r = byId.get(e.getKey());
                if (r == null) continue;
                Match m = TrendMatcher.assess(t, e.getValue());
                if (m.fit() == Fit.NONE) continue;
                Evidence ev = last7.byPhrase().getOrDefault(t.key(), Map.of()).getOrDefault(r.getId(), new Evidence(0, 0));
                int taps28 = last28.byPhrase().getOrDefault(t.key(), Map.of()).getOrDefault(r.getId(), new Evidence(0, 0)).taps();
                candidates.add(candidate(r, t, m, e.getValue(), ev, taps28, last28.restaurantTaps().getOrDefault(r.getId(), 0), runDate));
            }
        }

        LocalDate week = runDate.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
        List<OwnerSuggestion> history = suggestions.findByCreatedAtAfter(runDate.minusDays(60).atStartOfDay());
        Map<String, OwnerSuggestion> latest = new HashMap<>();
        for (OwnerSuggestion s : history) latest.merge(s.getRestaurantId() + "|" + s.getTrendKey(), s, (a, b) -> a.getCreatedAt().isAfter(b.getCreatedAt()) ? a : b);

        Map<String, List<Candidate>> byOwner = candidates.stream().collect(Collectors.groupingBy(c -> c.ownerId() != null ? "o" + c.ownerId() : "r" + c.restaurant().getId()));
        int created = 0, refreshed = 0, capped = 0, blocked = 0;
        Map<String, Integer> createdByType = new HashMap<>();
        for (List<Candidate> group : byOwner.values()) {
            Set<Integer> groupRestaurants = group.stream().map(c -> c.restaurant().getId()).collect(Collectors.toSet());
            long thisWeek = history.stream().filter(s -> week.equals(s.getWeekStart()) && groupRestaurants.contains(s.getRestaurantId())).count();
            for (Candidate c : group.stream().sorted(Comparator.comparingDouble(Candidate::score).reversed()).toList()) {
                OwnerSuggestion existing = latest.get(c.restaurant().getId() + "|" + c.trend().key());
                if (existing != null) {
                    switch (Status.valueOf(existing.getStatus())) {
                        case NEW -> { apply(existing, c); suggestions.save(existing); refreshed++; continue; }
                        case SNOOZED -> {
                            if (existing.getSnoozedUntil() != null && existing.getSnoozedUntil().isAfter(runDate)) { blocked++; continue; }
                            existing.setStatus(Status.NEW.name());
                            existing.setSnoozedUntil(null);
                            apply(existing, c);
                            suggestions.save(existing);
                            refreshed++;
                            continue;
                        }
                        case DISMISSED, ACTED -> {
                            if (existing.getUpdatedAt().isAfter(runDate.minusDays(DISMISS_COOLDOWN_DAYS).atStartOfDay())) { blocked++; continue; }
                        }
                        default -> { }
                    }
                }
                if (thisWeek >= WEEKLY_CAP) { capped++; continue; }
                OwnerSuggestion s = new OwnerSuggestion();
                s.setRestaurantId(c.restaurant().getId());
                s.setOwnerId(c.ownerId());
                s.setTrendKey(c.trend().key());
                s.setWeekStart(week);
                s.setRunDate(runDate);
                apply(s, c);
                suggestions.save(s);
                thisWeek++;
                created++;
                createdByType.merge(c.type().name(), 1, Integer::sum);
            }
        }

        Set<String> risingKeys = rising.stream().map(TrendView::key).collect(Collectors.toSet());
        int expired = 0;
        for (OwnerSuggestion s : suggestions.findByStatus(Status.NEW.name())) {
            if (!risingKeys.contains(s.getTrendKey()) && s.getUpdatedAt().isBefore(runDate.minusDays(7).atStartOfDay())) {
                s.setStatus(Status.EXPIRED.name());
                s.setUpdatedAt(LocalDateTime.now());
                suggestions.save(s);
                expired++;
            }
        }
        return new GenerateSummary(runDate, rising.size(), candidates.size(), created, refreshed, capped, blocked, expired, createdByType);
    }

    private void apply(OwnerSuggestion s, Candidate c) {
        s.setType(c.type().name());
        s.setTrendLabel(c.trend().label());
        s.setScore(Math.round(c.score() * 1000) / 1000.0);
        s.setHeadline(c.headline());
        s.setBody(c.body());
        s.setPayload(write(c.payload()));
        s.setRecentSearchers(c.trend().recentSearchers());
        s.setBaselineSearchers(c.trend().baselineSearchers());
        s.setGrowth(c.trend().growth());
        s.setUnmetShare(c.trend().unmetShare());
        s.setImpressions(c.evidence().impressions());
        s.setTaps(c.evidence().taps());
        s.setUpdatedAt(LocalDateTime.now());
    }

    private Candidate candidate(Restaurant r, TrendView t, Match m, List<DishDoc> menu, Evidence ev, int taps28, int restaurantTaps28, LocalDate runDate) {
        boolean has = m.fit() == Fit.HAS;
        boolean strong = t.recentSearchers() >= DROP_MIN_SEARCHERS && t.growth() >= DROP_MIN_GROWTH;
        Type type = !has ? Type.ADD_DISH : (strong && !m.dishes().isEmpty() ? Type.MAKE_DROP : Type.STOCK_UP);
        double score = Math.log1p(t.recentSearchers()) * Math.log1p(Math.min(t.growth(), 10)) * m.strength() * (type == Type.ADD_DISH ? 1 + t.unmetShare() : 1);
        Payload payload = switch (type) {
            case ADD_DISH -> addDish(r, t, menu);
            case STOCK_UP -> stockUp(m, t);
            case MAKE_DROP -> makeDrop(m, t, runDate);
        };
        if (type != Type.ADD_DISH) payload = payload.withEstimate(estimate(t, r.getId(), ev, taps28, restaurantTaps28, runDate));
        return new Candidate(r, r.getOwner() == null ? null : r.getOwner().getOwnerId(), t, m, type, score, ev, payload, headline(type, t, payload),
                body(type, t, m, ev, payload, r));
    }

    /**
     * Orders per tap, from delivered orders search really brought in over the last four weeks, applied to this week's taps. Needs at least
     * {@value #ESTIMATE_MIN_ORDERS} counted orders and {@value #ESTIMATE_MIN_TAPS} taps behind it; a new phrase falls back to the restaurant's own rate across
     * all search-driven orders. Without that history there is no estimate: nothing is invented.
     */
    private Estimate estimate(TrendView t, int restaurantId, Evidence week, int taps28, int restaurantTaps28, LocalDate runDate) {
        LocalDate since = runDate.minusDays(ESTIMATE_DAYS - 1);
        OrderAttributionService.Totals totals = attribution.totalsForPhrase(restaurantId, t.key(), since);
        int taps = taps28;
        String basis = "PHRASE";
        if (totals.orders() < ESTIMATE_MIN_ORDERS || taps < ESTIMATE_MIN_TAPS) {
            totals = attribution.totalsFor(Set.of(restaurantId), since);
            taps = restaurantTaps28;
            basis = "RESTAURANT";
            if (totals.orders() < ESTIMATE_MIN_ORDERS || taps < ESTIMATE_MIN_TAPS) return null;
        }
        int weekly = (int) Math.round(week.taps() * ((double) totals.orders() / taps));
        if (weekly < 1) return null;
        return new Estimate(weekly, Math.round(weekly * totals.averageOrderValue()), totals.orders(), taps, basis);
    }

    // ------------------------------------------------------------------ the three suggestions

    private Payload addDish(Restaurant r, TrendView t, List<DishDoc> menu) {
        Kind kind = Kind.valueOf(t.kind());
        String name = switch (kind) {
            case FLAVOR -> null;
            case FUSION -> dishLikeWording(t).orElse(t.label().replace(" fusion", " special"));
            case DISH -> titleCase(t.samples().isEmpty() ? t.label() : t.samples().get(0));
        };
        String description = switch (kind) {
            case FLAVOR -> null;
            case FUSION -> "Our take on " + name + ": " + t.cuisines().stream().map(CuisineLexicon::label).collect(Collectors.joining(" meets ")) + ".";
            case DISH -> "Our version of " + name + ".";
        };
        List<String> tags;
        if (kind == Kind.FLAVOR) {
            tags = Arrays.stream(t.key().substring(t.key().indexOf(':') + 1).split("\\+")).toList();
        } else {
            tags = index.autoTagger().suggest(name, description, null, null).stream().map(s -> s.flavor().id()).limit(3).toList();
        }
        return new Payload(name, description, tags, null, null, null, null, null, null, null, t.samples(), null);
    }

    private Payload stockUp(Match m, TrendView t) {
        DishDoc d = !m.dishes().isEmpty() ? bestDish(m.dishes()) : bestDish(m.unavailable());
        return new Payload(null, null, List.of(), d.itemId(), d.name(), (double) d.price(), d.available(), null, null, null, t.samples(), null);
    }

    private Payload makeDrop(Match m, TrendView t, LocalDate runDate) {
        DishDoc d = bestDish(m.dishes());
        int slots = (int) Math.max(10, Math.min(60, Math.round(t.recentSearchers() / 7.0)));
        LocalDateTime start = runDate.plusDays(1).atTime(18, 0);
        return new Payload(null, null, List.of(), d.itemId(), d.name(), (double) d.price(), true, slots, start.toString(), start.plusHours(3).toString(), t.samples(), null);
    }

    private static DishDoc bestDish(List<DishDoc> dishes) {
        return dishes.stream().min(Comparator.comparing(DishDoc::name).thenComparingInt(DishDoc::itemId)).orElseThrow();
    }

    /** A wording that reads like a dish, not like "X Y fusion": it points to every cuisine and does not just name them. */
    private static Optional<String> dishLikeWording(TrendView t) {
        for (String s : t.samples()) {
            if (s.contains("fusion")) continue;
            if (PhraseMiner.cuisinesIn(s).containsAll(t.cuisines())) return Optional.of(titleCase(s));
        }
        return Optional.empty();
    }

    private static String titleCase(String s) {
        return Arrays.stream(s.trim().split("\\s+")).map(w -> w.substring(0, 1).toUpperCase(Locale.ROOT) + w.substring(1)).collect(Collectors.joining(" "));
    }

    // ------------------------------------------------------------------ words the owner reads

    private static String headline(Type type, TrendView t, Payload p) {
        return switch (type) {
            case ADD_DISH -> "\"" + t.label() + "\" is trending and not on your menu";
            case STOCK_UP -> "Searches for \"" + t.label() + "\" are up " + times(t.growth()) + ": keep more " + p.dishName() + " ready";
            case MAKE_DROP -> "Turn " + p.dishName() + " into a Drop";
        };
    }

    private static String body(Type type, TrendView t, Match m, Evidence ev, Payload p, Restaurant r) {
        String demand = t.recentSearchers() + " people searched for it in the last 7 days, " + times(t.growth()) + " its usual level"
                + (t.baselineSearchers() > 0 ? " (about " + Math.max(1, Math.round(t.baselineSearchers() / 4.0)) + " a week before)." : " (it was almost never searched before).");
        return switch (type) {
            case ADD_DISH -> demand + (t.unmetShare() >= 0.5 ? " " + Math.round(t.unmetShare() * 100) + "% of those searches found no dish that matches." : "")
                    + (m.fit() == Fit.CUISINE ? " You serve " + cuisineNames(t, r) + ", so it fits your menu." : " It is close to dishes you already serve.")
                    + (ev.impressions() > 0 ? " Your menu showed up in " + ev.impressions() + " of those searches and was tapped " + ev.taps() + " times, so they are already looking at kitchens like yours." : "")
                    + (p.suggestedName() != null ? " Suggested dish: " + p.suggestedName() + "." : " Pick a dish that is both " + String.join(" and ", p.flavorTags()) + ".");
            case STOCK_UP -> demand + (Boolean.FALSE.equals(p.dishAvailable())
                    ? " Your " + p.dishName() + " is switched off right now; turning it back on would put it in front of them."
                    : " Your " + p.dishName() + " showed up in " + ev.impressions() + " of those searches and was tapped " + ev.taps() + " times. Prepare more than usual.")
                    + estimateText(p.estimate());
            case MAKE_DROP -> demand + " Your " + p.dishName() + " showed up in " + ev.impressions() + " of those searches and was tapped " + ev.taps()
                    + " times. A limited Drop of " + p.suggestedSlots() + " slots sells a known amount instead of risking waste, and rewards the people who searched."
                    + estimateText(p.estimate());
        };
    }

    /** The sentence about expected orders: counted history if there is enough of it, otherwise an honest "no estimate". */
    private static String estimateText(Estimate e) {
        if (e == null) return " No sales estimate yet: there are not enough delivered orders from search to base one on.";
        return " Over the last 4 weeks " + e.ordersObserved() + " delivered orders came from " + e.tapsObserved() + " taps"
                + (e.basis().equals("RESTAURANT") ? " on your dishes from searches like this (this phrase is new, so this is your overall rate)" : " on your dishes for this search")
                + ", so expect about " + e.weeklyOrders() + " orders (around ₹" + e.weeklyRevenue() + ") a week at this rate. A rough guide, not a promise.";
    }

    private static String cuisineNames(TrendView t, Restaurant r) {
        String declared = r.getCuisine() == null ? "" : r.getCuisine();
        Set<String> mine = PhraseMiner.cuisinesIn(declared);
        List<String> shared = t.cuisines().stream().filter(mine::contains).map(CuisineLexicon::label).toList();
        return shared.isEmpty() ? (declared.isBlank() ? "this kind of food" : declared) : String.join(" and ", shared);
    }

    private static String times(double growth) { return growth >= 10 ? Math.round(growth) + "×" : String.format(Locale.ROOT, "%.1f×", growth); }

    // ------------------------------------------------------------------ impressions and taps

    private record Counts(Map<String, Map<Integer, Evidence>> byPhrase, Map<Integer, Integer> restaurantTaps) {}

    /**
     * Since a date: for each rising phrase, how many searches showed each restaurant's dishes and how many were tapped; and, for each restaurant,
     * how many taps came from searches that count as a phrase at all (the base for its overall rate of orders per tap).
     */
    private Counts countsFor(Set<String> keys, LocalDateTime since) {
        Map<Long, Set<Integer>> tapped = new HashMap<>();
        for (Object[] c : events.clicksSince(since)) tapped.computeIfAbsent(((Number) c[0]).longValue(), k -> new HashSet<>()).add(((Number) c[1]).intValue());

        Map<String, Map<Integer, int[]>> counts = new HashMap<>();
        Map<Integer, Integer> restaurantTaps = new HashMap<>();
        Map<String, PhraseMiner.Phrase> mined = new HashMap<>();
        for (Object[] row : events.shownSince(since, props.simEnabled())) {
            String normalized = (String) row[1];
            String flavors = (String) row[2];
            String shown = (String) row[3];
            if (shown == null || shown.isBlank()) continue;
            PhraseMiner.Phrase p = mined.computeIfAbsent(normalized + "\u0001" + flavors, k -> PhraseMiner.mine(normalized, flavors));
            if (p == null) continue;
            long eventId = ((Number) row[0]).longValue();
            Set<Integer> taps = tapped.getOrDefault(eventId, Set.of());
            Set<Integer> restaurantsShown = new HashSet<>();
            Set<Integer> restaurantsTapped = new HashSet<>();
            for (String id : shown.split(",")) {
                int item = Integer.parseInt(id);
                index.doc(item).ifPresent(d -> {
                    restaurantsShown.add(d.restaurantId());
                    if (taps.contains(item)) restaurantsTapped.add(d.restaurantId());
                });
            }
            for (int rid : restaurantsTapped) restaurantTaps.merge(rid, 1, Integer::sum);
            if (!keys.contains(p.key())) continue;
            Map<Integer, int[]> perRestaurant = counts.computeIfAbsent(p.key(), k -> new HashMap<>());
            for (int rid : restaurantsShown) perRestaurant.computeIfAbsent(rid, k -> new int[2])[0]++;
            for (int rid : restaurantsTapped) perRestaurant.computeIfAbsent(rid, k -> new int[2])[1]++;
        }
        Map<String, Map<Integer, Evidence>> out = new HashMap<>();
        counts.forEach((k, m) -> {
            Map<Integer, Evidence> inner = new HashMap<>();
            m.forEach((rid, c) -> inner.put(rid, new Evidence(c[0], c[1])));
            out.put(k, inner);
        });
        return new Counts(out, restaurantTaps);
    }

    // ------------------------------------------------------------------ what owners and admins do with them

    /** Suggestions waiting for these restaurants, best first. Snoozes that have run out are not shown until the next nightly run revives them. */
    @Transactional(readOnly = true)
    public List<View> openFor(Collection<Integer> restaurantIds) {
        if (restaurantIds.isEmpty()) return List.of();
        return suggestions.findByRestaurantIdInAndStatusOrderByScoreDesc(restaurantIds, Status.NEW.name()).stream().map(this::view).toList();
    }

    @Transactional(readOnly = true)
    public List<View> all(String status) {
        List<OwnerSuggestion> rows = status == null || status.isBlank() ? suggestions.findAll() : suggestions.findByStatusOrderByScoreDesc(status.trim().toUpperCase(Locale.ROOT));
        return rows.stream().sorted(Comparator.comparingDouble(OwnerSuggestion::getScore).reversed()).map(this::view).toList();
    }

    @Transactional
    public Optional<View> dismiss(long id, Collection<Integer> allowedRestaurantIds) {
        return change(id, allowedRestaurantIds, s -> s.setStatus(Status.DISMISSED.name()));
    }

    @Transactional
    public Optional<View> snooze(long id, Collection<Integer> allowedRestaurantIds, LocalDate today) {
        return change(id, allowedRestaurantIds, s -> {
            s.setStatus(Status.SNOOZED.name());
            s.setSnoozedUntil(today.plusDays(SNOOZE_DAYS));
        });
    }

    /** The owner added the dish or created the Drop. */
    @Transactional
    public Optional<View> markActed(long id, Collection<Integer> allowedRestaurantIds) {
        return change(id, allowedRestaurantIds, s -> s.setStatus(Status.ACTED.name()));
    }

    /** Only a suggestion of an allowed restaurant that is still open can be changed; anything else answers empty, so ids cannot be probed. */
    private Optional<View> change(long id, Collection<Integer> allowed, java.util.function.Consumer<OwnerSuggestion> edit) {
        return suggestions.findById(id)
                .filter(s -> allowed.contains(s.getRestaurantId()))
                .filter(s -> Status.NEW.name().equals(s.getStatus()))
                .map(s -> {
                    edit.accept(s);
                    s.setUpdatedAt(LocalDateTime.now());
                    return view(suggestions.save(s));
                });
    }

    private View view(OwnerSuggestion s) {
        String name = restaurants.findById(s.getRestaurantId()).map(Restaurant::getName).orElse("restaurant " + s.getRestaurantId());
        return new View(s.getId(), s.getRestaurantId(), name, s.getType(), s.getStatus(), s.getTrendKey(), s.getTrendLabel(), s.getHeadline(), s.getBody(),
                s.getScore(), s.getRecentSearchers(), s.getBaselineSearchers(), s.getGrowth(), s.getUnmetShare(), s.getImpressions(), s.getTaps(),
                read(s.getPayload()), s.getSnoozedUntil(), s.getCreatedAt());
    }

    private String write(Payload p) {
        try {
            return json.writeValueAsString(p);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException(e);
        }
    }

    private Payload read(String s) {
        try {
            return s == null ? null : json.readValue(s, Payload.class);
        } catch (JsonProcessingException e) {
            log.warn("Unreadable suggestion payload: {}", e.getMessage());
            return null;
        }
    }
}
