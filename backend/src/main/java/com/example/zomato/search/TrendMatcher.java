package com.example.zomato.search;

import com.example.zomato.search.PhraseMiner.Kind;
import com.example.zomato.search.TrendService.TrendView;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;

/**
 * Decides how a rising phrase relates to one restaurant's menu, so the owner only hears about trends that are theirs to act on.
 *
 * <ul>
 *   <li>HAS: a dish already is the thing (all the words of a dish phrase, both cuisines of a fusion, all the flavors).</li>
 *   <li>CUISINE: no such dish, but the restaurant cooks one of the cuisines involved, so adding it would be natural.</li>
 *   <li>PARTIAL: no such dish and no cuisine link, but the restaurant has dishes sharing some of the words (a taco place and "birria taco").</li>
 *   <li>NONE: nothing links them; the owner is not told.</li>
 * </ul>
 */
final class TrendMatcher {

    enum Fit { HAS, CUISINE, PARTIAL, NONE }

    /** @param dishes available dishes that are the thing; @param unavailable matching dishes the owner has switched off */
    record Match(Fit fit, double strength, List<DishDoc> dishes, List<DishDoc> unavailable) {
        static final Match NONE = new Match(Fit.NONE, 0, List.of(), List.of());
    }

    private static final double STRONG_TAG = 0.6;

    private TrendMatcher() {}

    static Match assess(TrendView trend, List<DishDoc> menu) {
        if (menu.isEmpty()) return Match.NONE;
        Kind kind = Kind.valueOf(trend.kind());
        List<String> keyParts = List.of(trend.key().substring(trend.key().indexOf(':') + 1).split("\\+"));
        Map<DishDoc, Set<String>> terms = new HashMap<>();
        for (DishDoc d : menu) terms.put(d, new HashSet<>(PhraseMiner.canonicalTerms(text(d))));

        List<DishDoc> has = new ArrayList<>(), hasOff = new ArrayList<>(), partial = new ArrayList<>();
        for (DishDoc d : menu) {
            boolean all, some;
            switch (kind) {
                case FUSION -> {
                    Set<String> touched = new TreeSet<>();
                    for (String t : terms.get(d)) CuisineLexicon.cuisineOf(t).ifPresent(touched::add);
                    all = touched.containsAll(keyParts);
                    some = false;
                }
                case FLAVOR -> {
                    int n = 0;
                    for (String id : keyParts) if (strong(d, Flavor.fromId(id))) n++;
                    all = n == keyParts.size();
                    some = n > 0;
                }
                default -> {
                    int n = 0;
                    for (String t : keyParts) if (terms.get(d).contains(t)) n++;
                    all = n == keyParts.size();
                    some = n > 0 && keyParts.size() >= 2;
                }
            }
            if (all) (d.available() ? has : hasOff).add(d);
            else if (some && d.available()) partial.add(d);
        }
        if (!has.isEmpty()) return new Match(Fit.HAS, 1.0, has, hasOff);
        if (!hasOff.isEmpty()) return new Match(Fit.HAS, 1.0, List.of(), hasOff);

        if (kind != Kind.FLAVOR) {
            Set<String> trendCuisines = new HashSet<>(trend.cuisines());
            if (!trendCuisines.isEmpty() && restaurantCuisines(menu).stream().anyMatch(trendCuisines::contains)) {
                return new Match(Fit.CUISINE, 0.8, List.of(), List.of());
            }
        }
        if (!partial.isEmpty()) return new Match(Fit.PARTIAL, kind == Kind.FLAVOR ? 0.6 : 0.5, partial, List.of());
        return Match.NONE;
    }

    /** What the restaurant says it cooks, plus any cuisine that at least two of its dishes point to. */
    static Set<String> restaurantCuisines(List<DishDoc> menu) {
        Set<String> out = new TreeSet<>();
        String declared = menu.get(0).cuisine();
        if (declared != null) out.addAll(PhraseMiner.cuisinesIn(declared));
        Map<String, Integer> byDish = new HashMap<>();
        for (DishDoc d : menu) for (String c : PhraseMiner.cuisinesIn(text(d))) byDish.merge(c, 1, Integer::sum);
        byDish.forEach((c, n) -> { if (n >= 2) out.add(c); });
        return out;
    }

    private static boolean strong(DishDoc d, Flavor f) {
        if (f == null) return false;
        if (Boolean.TRUE.equals(d.ownerTags().get(f))) return true;
        return d.tags().getOrDefault(f, 0.0) >= STRONG_TAG;
    }

    private static String text(DishDoc d) {
        return d.name() + " " + nz(d.description()) + " " + nz(d.ingredients()) + " " + nz(d.category());
    }

    private static String nz(String s) { return s == null ? "" : s; }
}
