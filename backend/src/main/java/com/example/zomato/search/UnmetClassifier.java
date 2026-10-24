package com.example.zomato.search;

import com.example.zomato.search.HybridSearchService.Diagnostics;

/**
 * Decides whether a craving looks unserved by the current menus, from the absolute answer-quality signals (the hit scores
 * are relative to the best hit, so they cannot say this). A first cut: Phase 2 refines it for fusions such as
 * "Korean x Italian", where every word is served on its own but no dish combines them.
 *
 * Flavor cravings: unserved when not one of the top three dishes carries every requested flavor with an owner-confirmed tag
 * and the first dish covers under 80% of them.
 * Anything else (named dishes, cuisines, mixes of them): the words must meet in one dish. Unserved when a word is on no menu
 * at all, or when each word is served but no single dish has them all ("kimchi carbonara", "Korean Italian").
 * Embedding similarity cannot decide this: bge-small scores unrelated dishes 0.5 to 0.8 whatever is asked (see the calibration test).
 */
public final class UnmetClassifier {

    public static final int MIN_RELEVANT = 3;
    static final double FULL_COVERAGE = 0.8;

    public record Verdict(boolean unmet, String basis) {}

    private UnmetClassifier() {}

    public static Verdict judge(ParsedQuery q, Diagnostics d, boolean semantic) {
        if (d.relevantCount() == 0) return new Verdict(true, "nothing-relevant");
        if (!q.flavors().isEmpty()) {
            boolean covered = d.ownerCoveredTop3() >= 1 || (d.topCoverage() != null && d.topCoverage() >= FULL_COVERAGE);
            if (!covered) return new Verdict(true, "no-dish-carries-the-flavors");
            if (d.relevantCount() < MIN_RELEVANT) return new Verdict(true, "few-relevant");
            return new Verdict(false, "served");
        }
        if (d.terms() == 0) return new Verdict(false, "served");
        if (d.unknownTerms() > 0) return new Verdict(true, "word-on-no-menu");
        if (d.fullMatches() == 0) return new Verdict(true, "no-dish-has-all-the-words");
        return new Verdict(false, "served");
    }
}
