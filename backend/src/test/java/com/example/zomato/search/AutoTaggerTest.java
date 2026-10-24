package com.example.zomato.search;

import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.*;

class AutoTaggerTest {

    private final AutoTagger tagger = new AutoTagger(new NoEmbeddingProvider());

    private Set<Flavor> flavors(List<TagSuggestion> s) { return s.stream().map(TagSuggestion::flavor).collect(Collectors.toSet()); }

    @Test
    void picksUpKeywordCuesFromNameDescriptionAndIngredients() {
        var tags = flavors(tagger.suggest("Honey Hot Wings", "Crispy wings with a sticky glaze", "chicken, honey, chili flakes", "Chicken"));
        assertTrue(tags.containsAll(Set.of(Flavor.SWEET, Flavor.SPICY, Flavor.CRUNCHY)), tags.toString());
    }

    @Test
    void explainsEachSuggestion() {
        var s = tagger.suggest("Penne Arrabbiata", "Fiery tomato sauce", "penne, red chili", "Pasta");
        TagSuggestion spicy = s.stream().filter(t -> t.flavor() == Flavor.SPICY).findFirst().orElseThrow();
        assertFalse(spicy.reasons().isEmpty());
        assertTrue(spicy.confidence() >= AutoTagger.MIN_CONFIDENCE);
    }

    @Test
    void doesNotInventFlavorsFromNothing() {
        assertTrue(tagger.suggest("Plain Rice", "Boiled rice", "rice", "Sides").isEmpty());
        assertTrue(tagger.suggest(null, null, null, null).isEmpty());
    }

    @Test
    void wholeWordsOnly() {
        // "spicy" must not fire for "spice up"; "pie" must not fire inside "piece"
        var tags = flavors(tagger.suggest("Piece of Bread", "A plain piece of bread", "flour", "Bakery"));
        assertFalse(tags.contains(Flavor.SWEET));
    }

    @Test
    void returnsAtMostSixTagsBestFirst() {
        var s = tagger.suggest("Everything Bowl", "Crispy spicy sweet creamy smoky tangy rich comforting fresh light savory",
                "chili honey cheese bbq lime truffle", "Bowls");
        assertTrue(s.size() <= 6);
        for (int i = 1; i < s.size(); i++) assertTrue(s.get(i - 1).confidence() >= s.get(i).confidence());
    }
}
