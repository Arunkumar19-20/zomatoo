package com.example.zomato.search;

import com.example.zomato.search.HybridSearchService.Diagnostics;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

class UnmetClassifierTest {

    private static ParsedQuery plain(String q) { return new ParsedQuery(q, q, List.of(), false, null); }

    private static ParsedQuery flavored(String q) {
        return new ParsedQuery(q, q, List.of(new ParsedQuery.Facet("sweet", Set.of(Flavor.SWEET))), false, null);
    }

    private static Diagnostics d(int relevant, int terms, int unknown, int full, Double cover, int ownerTop3) {
        return new Diagnostics(relevant, relevant, terms, unknown, full, 0.6, cover, ownerTop3);
    }

    @Test
    void nothingRelevantIsUnmet() {
        var v = UnmetClassifier.judge(plain("xyz"), d(0, 1, 1, 0, null, 0), true);
        assertTrue(v.unmet());
        assertEquals("nothing-relevant", v.basis());
    }

    @Test
    void aWordOnNoMenuIsUnmetEvenWhenOtherWordsMatch() {
        var v = UnmetClassifier.judge(plain("kimchi carbonara"), d(3, 2, 1, 0, null, 0), true);
        assertTrue(v.unmet());
        assertEquals("word-on-no-menu", v.basis());
    }

    @Test
    void wordsServedSeparatelyButNeverTogetherAreUnmet() {
        var v = UnmetClassifier.judge(plain("vegan sushi burrito"), d(6, 3, 0, 0, null, 0), true);
        assertTrue(v.unmet());
        assertEquals("no-dish-has-all-the-words", v.basis());
    }

    @Test
    void aSingleExactDishIsServed() {
        assertFalse(UnmetClassifier.judge(plain("tiramisu"), d(1, 1, 0, 1, null, 0), true).unmet());
    }

    @Test
    void aCravingWithOnlyGenericWordsIsNotJudgedOnWords() {
        assertFalse(UnmetClassifier.judge(plain("something good"), d(20, 0, 0, 0, null, 0), true).unmet());
    }

    @Test
    void flavorCravingsNeedAnOwnerConfirmedDishOrFullCoverage() {
        assertTrue(UnmetClassifier.judge(flavored("sweet"), d(30, 1, 0, 30, 0.5, 0), true).unmet());
        assertFalse(UnmetClassifier.judge(flavored("sweet"), d(30, 1, 0, 30, 0.5, 1), true).unmet());
        assertFalse(UnmetClassifier.judge(flavored("sweet"), d(30, 1, 0, 30, 1.0, 0), true).unmet());
        assertEquals("few-relevant", UnmetClassifier.judge(flavored("sweet"), d(2, 1, 0, 2, 1.0, 2), true).basis());
    }
}
