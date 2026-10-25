package com.example.zomato.search;

import com.example.zomato.search.TrendDetector.Params;
import com.example.zomato.search.TrendDetector.Series;
import com.example.zomato.search.TrendDetector.Status;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

class TrendDetectorTest {

    private static final LocalDate TODAY = LocalDate.of(2026, 10, 25);
    private static final Params P = Params.defaults();

    /** searchers per day, index 0 = today, 1 = yesterday ... */
    private static Series series(int... perDayNewestFirst) {
        Map<LocalDate, Integer> m = new HashMap<>();
        for (int i = 0; i < perDayNewestFirst.length; i++) if (perDayNewestFirst[i] > 0) m.put(TODAY.minusDays(i), perDayNewestFirst[i]);
        return new Series("k", PhraseMiner.Kind.DISH, "label", Set.of(), m, 20, 10, List.of("q"));
    }

    private static int[] repeat(int value, int times) {
        int[] a = new int[times];
        java.util.Arrays.fill(a, value);
        return a;
    }

    private static int[] concat(int[] a, int[] b) {
        int[] r = new int[a.length + b.length];
        System.arraycopy(a, 0, r, 0, a.length);
        System.arraycopy(b, 0, r, a.length, b.length);
        return r;
    }

    @Test
    void aRampThatStartedThisWeekIsRising() {
        // today 28, 24, 20, 16, 13, 10, 8 searchers, nothing before
        var t = TrendDetector.assess(series(28, 24, 20, 16, 13, 10, 8), TODAY, P);
        assertEquals(Status.RISING, t.status(), t.reason());
        assertEquals(7, t.activeDays());
        assertTrue(t.growth() > 5);
    }

    @Test
    void aPopularButUnchangedPhraseIsSteady() {
        var t = TrendDetector.assess(series(repeat(12, 35)), TODAY, P);
        assertEquals(Status.STEADY, t.status(), t.reason());
    }

    @Test
    void aOneDaySpikeIsAFluke() {
        var t = TrendDetector.assess(series(0, 0, 45), TODAY, P);
        assertEquals(Status.FLUKE, t.status(), t.reason());
    }

    @Test
    void tooFewPeopleIsTooSmallEvenIfAllNew() {
        var t = TrendDetector.assess(series(1, 1, 1, 1, 1), TODAY, P);
        assertEquals(Status.TOO_SMALL, t.status());
    }

    @Test
    void aPhraseFadingFromItsPeakIsFalling() {
        var t = TrendDetector.assess(series(concat(new int[]{1, 1, 1, 1, 1, 1, 1}, repeat(10, 28))), TODAY, P);
        assertEquals(Status.TOO_SMALL, t.status(), "7 searchers is below the bar");
        var t2 = TrendDetector.assess(series(concat(new int[]{2, 2, 2, 2, 2, 2, 2}, repeat(10, 28))), TODAY, P);
        assertEquals(Status.FALLING, t2.status(), t2.reason());
    }

    @Test
    void growthIsMeasuredAgainstItsOwnBaseline() {
        // 10 a day before, 14 a day now: up, but not 2x
        var t = TrendDetector.assess(series(concat(repeat(14, 7), repeat(10, 28))), TODAY, P);
        assertEquals(Status.STEADY, t.status());
        // 3 a day before, 14 a day now: genuinely new demand
        var t2 = TrendDetector.assess(series(concat(repeat(14, 7), repeat(3, 28))), TODAY, P);
        assertEquals(Status.RISING, t2.status(), t2.reason());
    }

    @Test
    void searchesOutsideTheWindowAreIgnored() {
        var t = TrendDetector.assess(series(concat(repeat(0, 40), repeat(50, 5))), TODAY, P);
        assertEquals(Status.TOO_SMALL, t.status());
    }
}
