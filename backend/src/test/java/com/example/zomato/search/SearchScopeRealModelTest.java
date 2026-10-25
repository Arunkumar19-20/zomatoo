package com.example.zomato.search;

import com.example.zomato.search.HybridSearchService.Scope;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

/**
 * With the real embedding model: a dish-name search must not be padded with whatever is nearest in meaning ("pasta" used to end with
 * Tiramisu), and each filter must answer what it says. Skipped when the model is not installed.
 */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:scope_real;DB_CLOSE_DELAY=-1;MODE=PostgreSQL")
class SearchScopeRealModelTest {

    @Autowired SeedDishLoader seeds;
    @Autowired HybridSearchService search;
    @Autowired SearchIndexService index;

    @BeforeAll
    static void requireModel() {
        assumeTrue(Files.isRegularFile(Path.of("models/bge-small-en-v1.5/model.onnx")), "model not installed, skipping");
    }

    private HybridSearchService.Result run(String q, Scope scope) {
        seeds.load(true);
        return search.search(new HybridSearchService.Request(q, 10, null, null, false, scope));
    }

    private static List<String> names(HybridSearchService.Result r) { return r.hits().stream().map(h -> h.doc().name()).toList(); }

    private static List<String> words(DishDoc d) {
        return Bm25Index.tokenize(d.name() + " " + d.description() + " " + d.ingredients() + " " + d.category());
    }

    @Test
    void pastaIsPastaAndNotTiramisu() {
        var r = run("pasta", Scope.ALL);
        assertEquals("HYBRID", r.mode(), "this has to run on the real model");
        assertTrue(names(r).containsAll(List.of("Spaghetti Carbonara", "Fettuccine Alfredo")), names(r).toString());
        for (String notPasta : List.of("Tiramisu", "Greek Salad", "Caprese Salad", "Mushroom Risotto")) {
            assertFalse(names(r).contains(notPasta), notPasta + " is near pasta in meaning, but it is not pasta: " + names(r));
        }
        assertEquals(r.hits().size(), r.total(), "fewer than ten real matches: the total is the number shown");
        r.hits().forEach(h -> assertTrue(words(h.doc()).contains("pasta"), h.doc().name()));
    }

    @Test
    void otherDishNamesAreNotPaddedEither() {
        var pizza = run("pizza", Scope.ALL);
        for (String n : List.of("Lasagna al Forno", "Greek Salad", "Garlic Bread with Cheese")) assertFalse(names(pizza).contains(n), n);
        assertTrue(pizza.total() <= 8, "pizza matches a handful of dishes, not the menu: " + pizza.total());
        assertTrue(names(run("dessert", Scope.ALL)).contains("Tiramisu"), "the cutoff keeps what really matches");
    }

    @Test
    void theDishFilterNeedsEveryFoodWord() {
        assertEquals(List.of("Beef Birria Tacos"), names(run("birria tacos", Scope.DISH)));
        var noodles = run("spicy noodles", Scope.DISH);
        assertFalse(noodles.hits().isEmpty());
        noodles.hits().forEach(h -> assertTrue(words(h.doc()).contains("noodle"), h.doc().name()));
    }

    @Test
    void aCravingSentenceIsNotBrokenByTheDishFilter() {
        String q = "something sweet but also spicy";
        assertEquals(names(run(q, Scope.ALL)), names(run(q, Scope.DISH)), "no food word in it, so the dish filter changes nothing");
    }

    @Test
    void theCravingFilterFollowsTasteNotNames() {
        var r = run("something sweet but also spicy", Scope.CRAVING);
        for (var h : r.hits().subList(0, 3)) {
            assertTrue(h.doc().tags().containsKey(Flavor.SWEET) && h.doc().tags().containsKey(Flavor.SPICY), h.doc().name() + " should carry both flavors");
        }
        assertTrue(r.total() >= 10);
    }

    @Test
    void meaningStillFillsInWhenNoWordMatches() {
        var r = run("late night snack", Scope.ALL);
        assertFalse(r.hits().isEmpty(), "no menu says 'late night', but snacks are close in meaning");
        assertEquals(0, run("injera", Scope.ALL).total(), "unrelated words still find nothing");
    }

    @Test
    void theUnmetVerdictDoesNotChangeBecauseOfTheCutoff() {
        // the search log judges "was this served?" from relevance by words, flavors and meaning together, whatever the filter shows
        var all = run("injera", Scope.ALL).diagnostics();
        var dish = run("injera", Scope.DISH).diagnostics();
        assertEquals(all.relevantCount(), dish.relevantCount());
        assertEquals(0, all.relevantCount());
        assertEquals(run("pasta", Scope.ALL).diagnostics().relevantCount(), run("pasta", Scope.CRAVING).diagnostics().relevantCount());
    }
}
