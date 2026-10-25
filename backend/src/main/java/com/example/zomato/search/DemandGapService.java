package com.example.zomato.search;

import com.example.zomato.entity.Restaurant;
import com.example.zomato.repository.RestaurantRepository;
import com.example.zomato.repository.SearchEventRepository;
import com.example.zomato.search.PhraseMiner.Phrase;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;

/**
 * Where customers want something no restaurant on the platform offers yet, for the admin who decides which kinds of restaurants to bring in.
 *
 * Takes the searches that found nothing, folds different wordings of the same craving into one phrase (see {@link PhraseMiner}), counts
 * searcher-days (distinct searchers per day, summed), and groups the phrases by cuisine next to how many restaurants declare that cuisine.
 * A cuisine nobody serves is a hole in the supply; a cuisine that is served but still has unmet cravings is a dish or combination gap.
 * A fusion such as "kimchi carbonara" is listed under each of its cuisines.
 *
 * Phrases fewer than {@code minSearcherDays} people looked for are left out, so nothing rests on one person's search.
 */
@Service
public class DemandGapService {

    public static final int DEFAULT_DAYS = 14;
    public static final int DEFAULT_MIN_SEARCHER_DAYS = 5;
    /** Never lower than this, whatever the caller asks for: a "gap" of one or two people is not a pattern. */
    public static final int FLOOR_MIN_SEARCHER_DAYS = 3;
    private static final String OTHER = "other";

    private final SearchEventRepository events;
    private final RestaurantRepository restaurants;
    private final SearchProperties props;

    public DemandGapService(SearchEventRepository events, RestaurantRepository restaurants, SearchProperties props) {
        this.events = events;
        this.restaurants = restaurants;
        this.props = props;
    }

    public record Gap(String key, String label, String kind, int searcherDays, int activeDays, List<String> alsoCuisines, List<String> examples) {}

    /** {@code restaurantsServing} is null for the group of cravings that name no cuisine. */
    public record Group(String cuisine, String label, String status, int searcherDays, Integer restaurantsServing, Integer openRestaurantsServing, List<Gap> gaps) {}

    public record Report(LocalDate from, LocalDate to, int days, int minSearcherDays, int unmetSearches, int phrasesShown, int phrasesBelowMinimum, List<Group> groups) {}

    private static final class Acc {
        final Phrase phrase;
        final Map<LocalDate, Set<String>> searchers = new TreeMap<>();
        final Map<String, Integer> forms = new HashMap<>();
        Acc(Phrase p) { this.phrase = p; }
        int searcherDays() { return searchers.values().stream().mapToInt(Set::size).sum(); }
    }

    @Transactional(readOnly = true)
    public Report report(int days, int minSearcherDays) {
        days = Math.max(1, Math.min(days, 90));
        minSearcherDays = Math.max(FLOOR_MIN_SEARCHER_DAYS, minSearcherDays);
        LocalDate to = LocalDate.now();
        LocalDate from = to.minusDays(days - 1L);
        LocalDateTime since = from.atStartOfDay();

        Map<String, Acc> byKey = new LinkedHashMap<>();
        Map<String, Phrase> mined = new HashMap<>();
        int unmetSearches = 0;
        for (Object[] r : events.unmetSince(since, props.simEnabled())) {
            unmetSearches++;
            LocalDate day = ((LocalDateTime) r[0]).toLocalDate();
            String normalized = (String) r[1];
            String flavors = (String) r[2];
            String session = (String) r[3];
            Phrase p = mined.computeIfAbsent(normalized + "\u0001" + flavors, k -> PhraseMiner.mine(normalized, flavors));
            if (p == null) continue;
            Acc a = byKey.computeIfAbsent(p.key(), k -> new Acc(p));
            a.searchers.computeIfAbsent(day, k -> new HashSet<>()).add(session == null ? "?" : session);
            a.forms.merge(normalized, 1, Integer::sum);
        }

        Map<String, int[]> supply = supplyByCuisine();
        Map<String, List<Gap>> gapsBy = new LinkedHashMap<>();
        int shown = 0, below = 0;
        for (Acc a : byKey.values()) {
            if (a.searcherDays() < minSearcherDays) { below++; continue; }
            shown++;
            Set<String> cuisines = a.phrase.cuisines();
            List<String> targets = cuisines.isEmpty() ? List.of(OTHER) : new ArrayList<>(new TreeSet<>(cuisines));
            for (String c : targets) {
                List<String> also = cuisines.stream().filter(x -> !x.equals(c)).sorted().toList();
                gapsBy.computeIfAbsent(c, k -> new ArrayList<>()).add(new Gap(a.phrase.key(), a.phrase.label(), a.phrase.kind().name(),
                        a.searcherDays(), a.searchers.size(), also, topForms(a, 3)));
            }
        }

        List<Group> groups = new ArrayList<>();
        gapsBy.forEach((cuisine, gaps) -> {
            gaps.sort(Comparator.comparingInt(Gap::searcherDays).reversed().thenComparing(Gap::key));
            int demand = gaps.stream().mapToInt(Gap::searcherDays).sum();
            if (OTHER.equals(cuisine)) {
                groups.add(new Group(OTHER, "Other cravings", "NO_CUISINE", demand, null, null, gaps));
            } else {
                int[] s = supply.getOrDefault(cuisine, new int[]{0, 0});
                groups.add(new Group(cuisine, CuisineLexicon.label(cuisine), s[0] == 0 ? "NO_RESTAURANT" : "DISH_GAP", demand, s[0], s[1], gaps));
            }
        });
        groups.sort(Comparator.comparingInt(Group::searcherDays).reversed().thenComparing(Group::cuisine));
        return new Report(from, to, days, minSearcherDays, unmetSearches, shown, below, groups);
    }

    /** cuisine -> {restaurants declaring it, of which open}, from each restaurant's own cuisine text */
    private Map<String, int[]> supplyByCuisine() {
        Map<String, int[]> out = new HashMap<>();
        for (Restaurant r : restaurants.findAll()) {
            for (String c : PhraseMiner.cuisinesIn(r.getCuisine() == null ? "" : r.getCuisine())) {
                int[] s = out.computeIfAbsent(c, k -> new int[2]);
                s[0]++;
                if (Boolean.TRUE.equals(r.getOpen())) s[1]++;
            }
        }
        return out;
    }

    private static List<String> topForms(Acc a, int n) {
        return a.forms.entrySet().stream()
                .sorted(Map.Entry.<String, Integer>comparingByValue().reversed().thenComparing(Map.Entry.comparingByKey()))
                .limit(n).map(Map.Entry::getKey).toList();
    }
}
