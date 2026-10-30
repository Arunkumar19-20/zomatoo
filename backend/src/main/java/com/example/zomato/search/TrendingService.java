package com.example.zomato.search;

import com.example.zomato.search.PhraseMiner.Kind;
import com.example.zomato.search.TrendMatcher.Fit;
import com.example.zomato.search.TrendService.TrendView;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * "Trending cravings" chips for customers: rising phrases that someone can actually order today. A phrase no menu serves (the
 * Korean x Italian fusion nobody makes yet) is a signal for restaurants, not a chip, because tapping it would show nothing.
 * Only phrases that already cleared the trend job's bars appear, so no chip reflects a handful of people.
 */
@Service
public class TrendingService {

    public static final int MAX_CHIPS = 12;

    /** @param query what tapping the chip searches for; @param dishCount how many available dishes match it right now */
    public record Chip(String label, String query, String kind, int dishCount) {}

    private final TrendService trends;
    private final SearchIndexService index;

    public TrendingService(TrendService trends, SearchIndexService index) {
        this.trends = trends;
        this.index = index;
    }

    @Transactional(readOnly = true)
    public List<Chip> chips(int limit) {
        return chips(limit, null);
    }

    /** With an area, what is rising among people searching from there comes first, then what is rising everywhere. */
    @Transactional(readOnly = true)
    public List<Chip> chips(int limit, String area) {
        int max = Math.max(1, Math.min(limit, MAX_CHIPS));
        Map<Integer, List<DishDoc>> menus = index.allDocs().stream().collect(Collectors.groupingBy(DishDoc::restaurantId));
        List<Chip> out = new ArrayList<>();
        List<TrendView> candidates = new ArrayList<>();
        if (TrendService.normalizeArea(area) != null) {
            candidates.addAll(trends.latest("RISING", area).stream().sorted(Comparator.comparingDouble(TrendView::growth).reversed()).toList());
        }
        java.util.Set<String> local = candidates.stream().map(TrendView::key).collect(Collectors.toSet());
        trends.latest("RISING").stream().filter(t -> !local.contains(t.key())).sorted(Comparator.comparingDouble(TrendView::growth).reversed()).forEach(candidates::add);
        for (TrendView t : candidates) {
            int dishes = 0;
            for (List<DishDoc> menu : menus.values()) {
                var m = TrendMatcher.assess(t, menu);
                if (m.fit() == Fit.HAS) dishes += m.dishes().size();
            }
            if (dishes == 0) continue;
            out.add(new Chip(chipLabel(t), chipQuery(t), t.kind(), dishes));
            if (out.size() >= max) break;
        }
        return out;
    }

    private static String chipLabel(TrendView t) {
        return t.kind().equals(Kind.FUSION.name()) ? t.label().replace(" fusion", "") : t.label();
    }

    /** What to type into the search box for this chip, in words the search understands. */
    static String chipQuery(TrendView t) {
        String body = t.key().substring(t.key().indexOf(':') + 1);
        return switch (Kind.valueOf(t.kind())) {
            case FLAVOR -> Arrays.stream(body.split("\\+")).collect(Collectors.joining(" and ")).toLowerCase(Locale.ROOT);
            case FUSION -> t.samples().stream().filter(s -> !s.contains("fusion")).findFirst().orElse(t.label());
            case DISH -> t.label().toLowerCase(Locale.ROOT);
        };
    }
}
