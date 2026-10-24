package com.example.zomato.search;

import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

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
}
