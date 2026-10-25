package com.example.zomato.search;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Decides which phrases are genuinely rising. Counts are searchers per day (one person typing a phrase fifty times is one),
 * the last 7 days are compared with the 28 before them, and a phrase has to clear four bars:
 * enough people, growth over its own baseline, spread over several days, and not one day's spike.
 */
public final class TrendDetector {

    public enum Status { RISING, STEADY, FALLING, FLUKE, TOO_SMALL }

    public record Params(int recentDays, int baselineDays, int minSearchers, int minActiveDays, double minGrowth, double maxDayShare, double epsilonPerDay) {
        public static Params defaults() { return new Params(7, 28, 8, 3, 2.0, 0.5, 0.25); }
    }

    /** What the nightly job knows about one phrase. */
    public record Series(String key, PhraseMiner.Kind kind, String label, Set<String> cuisines, Map<LocalDate, Integer> searchersPerDay,
                         int recentSearches, int recentUnmet, List<String> samples) {}

    public record Trend(Series series, Status status, String reason, int recentSearchers, int baselineSearchers, double growth,
                        int activeDays, double topDayShare, double unmetShare) {}

    private TrendDetector() {}

    public static Trend assess(Series s, LocalDate asOf, Params p) {
        LocalDate recentFrom = asOf.minusDays(p.recentDays() - 1L);
        LocalDate baselineFrom = recentFrom.minusDays(p.baselineDays());
        int recent = 0, baseline = 0, active = 0, peak = 0;
        for (var e : s.searchersPerDay().entrySet()) {
            LocalDate d = e.getKey();
            int n = e.getValue();
            if (!d.isBefore(recentFrom) && !d.isAfter(asOf)) {
                recent += n;
                if (n > 0) active++;
                peak = Math.max(peak, n);
            } else if (!d.isBefore(baselineFrom) && d.isBefore(recentFrom)) {
                baseline += n;
            }
        }
        double growth = ((double) recent / p.recentDays() + p.epsilonPerDay()) / ((double) baseline / p.baselineDays() + p.epsilonPerDay());
        double topShare = recent == 0 ? 0 : (double) peak / recent;
        double unmet = s.recentSearches() == 0 ? 0 : (double) s.recentUnmet() / s.recentSearches();

        if (recent < p.minSearchers()) {
            return new Trend(s, Status.TOO_SMALL, recent + " searchers in " + p.recentDays() + " days, need " + p.minSearchers(), recent, baseline, growth, active, topShare, unmet);
        }
        if (growth < p.minGrowth()) {
            Status st = growth < 0.7 ? Status.FALLING : Status.STEADY;
            return new Trend(s, st, String.format("%.1fx its usual level, need %.1fx", growth, p.minGrowth()), recent, baseline, growth, active, topShare, unmet);
        }
        if (active < p.minActiveDays() || topShare > p.maxDayShare()) {
            return new Trend(s, Status.FLUKE, String.format("%d%% of the searches came on one day over %d active day(s)", Math.round(topShare * 100), active),
                    recent, baseline, growth, active, topShare, unmet);
        }
        return new Trend(s, Status.RISING, String.format("%d searchers in %d days, %.1fx its usual level, on %d different days", recent, p.recentDays(), growth, active),
                recent, baseline, growth, active, topShare, unmet);
    }
}
