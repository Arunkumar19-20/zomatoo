package com.example.zomato.search;

import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

class QueryParserTest {

    private final QueryParser parser = new QueryParser();

    private static List<String> texts(ParsedQuery q) { return q.facets().stream().map(ParsedQuery.Facet::text).toList(); }

    @Test
    void splitsSweetButAlsoSpicyIntoTwoFlavorFacets() {
        ParsedQuery q = parser.parse("Something sweet but also spicy");
        assertEquals(List.of("sweet", "spicy"), texts(q));
        assertEquals(Set.of(Flavor.SWEET, Flavor.SPICY), q.flavors());
        assertTrue(q.isMultiFacet());
    }

    @Test
    void stripsFillerFromCravings() {
        ParsedQuery q = parser.parse("I'm craving something creamy and comforting please");
        assertEquals(List.of("creamy", "comforting"), texts(q));
        assertEquals(Set.of(Flavor.CREAMY, Flavor.COMFORT), q.flavors());
    }

    @Test
    void dishNamesWithAndStayWholeBecauseNoFlavorIsNamed() {
        ParsedQuery q = parser.parse("mac and cheese");
        assertEquals(1, q.facets().size());
        assertEquals("mac and cheese", q.facets().get(0).text());
    }

    @Test
    void sweetAndSourIsOneIdeaNotTwo() {
        ParsedQuery q = parser.parse("sweet and sour");
        assertEquals(1, q.facets().size());
        assertTrue(q.flavors().containsAll(Set.of(Flavor.SWEET, Flavor.SOUR)));
    }

    @Test
    void contentWordsBecomeTheirOwnFacetWhenAFlavorIsPresent() {
        ParsedQuery q = parser.parse("creamy with mushrooms");
        assertEquals(List.of("creamy", "mushrooms"), texts(q));
        assertEquals(Set.of(Flavor.CREAMY), q.flavors());
    }

    @Test
    void extractsVegetarianAndPriceFilters() {
        ParsedQuery q = parser.parse("spicy vegetarian under 300");
        assertTrue(q.vegOnly());
        assertEquals(300f, q.maxPrice());
        assertEquals(Set.of(Flavor.SPICY), q.flavors());
        assertEquals("spicy", q.facets().get(0).text());

        ParsedQuery rupee = parser.parse("dessert ₹150 or less");
        assertEquals(150f, rupee.maxPrice());
    }

    @Test
    void understandsSynonymsAndPlurals() {
        assertEquals(Set.of(Flavor.CRUNCHY, Flavor.TANGY), parser.parse("crispy and zesty").flavors());
        assertEquals(Set.of(Flavor.SPICY), parser.parse("fiery").flavors());
        assertEquals(Set.of(Flavor.COMFORT), parser.parse("cozy").flavors());
    }

    @Test
    void capsTheNumberOfFacetsAndNeverReturnsNone() {
        ParsedQuery many = parser.parse("sweet, spicy, crunchy, creamy, smoky, tangy");
        assertEquals(QueryParser.MAX_FACETS, many.facets().size());
        assertFalse(parser.parse("???").facets().isEmpty());
    }
}
