package com.example.zomato.search;

import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

class Bm25IndexTest {

    private Bm25Index index() {
        Bm25Index i = new Bm25Index();
        i.upsert(1, Map.of("Margherita Pizza", 3, "tomato mozzarella basil", 1));
        i.upsert(2, Map.of("Butter Chicken", 3, "creamy tomato gravy", 1));
        i.upsert(3, Map.of("Chocolate Brownie", 3, "fudgy chocolate", 1));
        return i;
    }

    @Test
    void findsExactWordsAndPlurals() {
        assertEquals(1, index().search("pizza", id -> true, 5).get(0).id());
        assertEquals(3, index().search("brownies", id -> true, 5).get(0).id());
    }

    @Test
    void toleratesTyposAndPrefixes() {
        assertEquals(1, index().search("margarita", id -> true, 5).get(0).id());
        assertEquals(2, index().search("buter chiken", id -> true, 5).get(0).id());
        assertEquals(3, index().search("choc", id -> true, 5).get(0).id());
    }

    @Test
    void honoursFiltersAndUpdates() {
        Bm25Index i = index();
        assertTrue(i.search("pizza", id -> id != 1, 5).isEmpty());
        i.remove(1);
        assertTrue(i.search("pizza", id -> true, 5).isEmpty());
        i.upsert(1, Map.of("Pizza Bianca", 3));
        assertEquals(List.of(1), i.search("pizza", id -> true, 5).stream().map(Bm25Index.Scored::id).toList());
    }

    @Test
    void rarerWordsOutweighCommonOnes() {
        Bm25Index i = new Bm25Index();
        i.upsert(1, Map.of("tomato soup", 1));
        i.upsert(2, Map.of("tomato pasta", 1));
        i.upsert(3, Map.of("tomato salad", 1));
        i.upsert(4, Map.of("tomato harissa", 1));
        assertEquals(4, i.search("tomato harissa", id -> true, 5).get(0).id());
    }

    private Bm25Index menu() {
        Bm25Index i = new Bm25Index();
        i.upsert(1, Map.of("Spaghetti Carbonara", 3, "pasta with egg and cheese", 1));
        i.upsert(2, Map.of("Penne Arrabbiata", 3, "spicy pasta in tomato sauce", 1));
        i.upsert(3, Map.of("Tiramisu", 3, "coffee dessert italian", 1));
        i.upsert(4, Map.of("Spicy Miso Ramen", 3, "noodles in a hot broth", 1));
        i.upsert(5, Map.of("Pad Thai", 3, "stir fried rice noodles", 1));
        return i;
    }

    @Test
    void matchAllRequiresEveryFoodWord() {
        var m = menu().matchAll("pasta", w -> false, id -> true);
        assertTrue(m.hadTerms());
        assertEquals(Set.of(1, 2), m.ids(), "tiramisu is Italian, not pasta");
        assertEquals(Set.of(2), menu().matchAll("spicy pasta", w -> false, id -> true).ids(), "both words, in one dish");
        assertEquals(Set.of(), menu().matchAll("pasta noodles", w -> false, id -> true).ids(), "words that never meet match nothing");
    }

    @Test
    void matchAllIgnoresFlavorAndMoodWordsButNotFood() {
        var m = menu().matchAll("spicy noodles", PhraseMiner::isFlavorOrMood, id -> true);
        assertEquals(Set.of(4, 5), m.ids(), "'spicy' is not required, 'noodles' is");
        assertEquals(Set.of(1, 2), menu().matchAll("late night pasta", PhraseMiner::isFlavorOrMood, id -> true).ids());
    }

    @Test
    void matchAllSaysWhenThereIsNoFoodWordAtAll() {
        for (String craving : List.of("sweet but also spicy", "late night snack", "something to share", "a little bit more")) {
            var m = menu().matchAll(craving, PhraseMiner::isFlavorOrMood, id -> true);
            assertFalse(m.hadTerms(), craving + " names no food");
        }
    }

    @Test
    void matchAllFindsNothingForAWordNoMenuHasAndHonoursFilters() {
        assertTrue(menu().matchAll("injera", w -> false, id -> true).ids().isEmpty());
        assertTrue(menu().matchAll("pasta injera", w -> false, id -> true).ids().isEmpty(), "one unknown word is enough to match nothing");
        assertEquals(Set.of(2), menu().matchAll("pasta", w -> false, id -> id != 1).ids());
    }

    @Test
    void matchAllToleratesPluralsAndSmallTypos() {
        assertEquals(Set.of(4, 5), menu().matchAll("noodle", w -> false, id -> true).ids());
        assertEquals(Set.of(1, 2), menu().matchAll("pastas", w -> false, id -> true).ids());
        assertEquals(Set.of(3), menu().matchAll("tiramsu", w -> false, id -> true).ids());
    }
}
