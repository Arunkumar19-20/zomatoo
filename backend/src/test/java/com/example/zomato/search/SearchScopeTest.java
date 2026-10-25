package com.example.zomato.search;

import com.example.zomato.search.HybridSearchService.Scope;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.test.web.servlet.MockMvc;

import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** The relevance cutoff and the {@code type} filter over the HTTP API. Keyword mode, so it needs no model. */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:search_scope;DB_CLOSE_DELAY=-1;MODE=PostgreSQL")
@AutoConfigureMockMvc
@Import(SearchScopeTest.Cfg.class)
class SearchScopeTest {

    @TestConfiguration
    static class Cfg {
        @Bean
        @Primary
        EmbeddingProvider none() { return new NoEmbeddingProvider(); }
    }

    @Autowired MockMvc mvc;
    @Autowired SeedDishLoader seeds;
    @Autowired SearchIndexService index;
    private final ObjectMapper json = new ObjectMapper();

    private JsonNode search(String q, String type) throws Exception {
        var req = get("/search/dishes").param("q", q).param("k", "30");
        if (type != null) req.param("type", type);
        return json.readTree(mvc.perform(req).andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
    }

    private static List<String> names(JsonNode res) {
        List<String> out = new ArrayList<>();
        res.get("hits").forEach(h -> out.add(h.get("name").asText()));
        return out;
    }

    @Test
    void aDishNameSearchReturnsOnlyDishesThatAreThatDish() throws Exception {
        seeds.load();
        JsonNode res = search("pasta", null);
        assertFalse(res.get("hits").isEmpty());
        assertFalse(names(res).contains("Tiramisu"), "tiramisu is Italian, not pasta: " + names(res));
        assertEquals(res.get("hits").size(), res.get("total").asInt(), "the total counts what is shown, not every dish on the platform");
        for (JsonNode h : res.get("hits")) {
            DishDoc d = index.doc(h.get("itemId").asInt()).orElseThrow();
            List<String> words = Bm25Index.tokenize(d.name() + " " + d.description() + " " + d.ingredients() + " " + d.category());
            assertTrue(words.contains("pasta"), d.name() + " is shown for \"pasta\" but never says pasta: " + words);
        }
    }

    @Test
    void theDishFilterRequiresEveryFoodWordAndIgnoresFlavorWords() throws Exception {
        seeds.load();
        JsonNode birria = search("birria tacos", "dish");
        assertEquals(List.of("Beef Birria Tacos"), names(birria), "only the dish that is both");
        assertTrue(names(search("birria tacos", null)).size() >= names(birria).size(), "everything may also show the partial match");

        JsonNode noodles = search("spicy noodles", "dish");
        assertFalse(noodles.get("hits").isEmpty());
        for (String n : names(noodles)) assertFalse(n.toLowerCase().contains("cookie"), "'spicy' is not a food word, so a spicy cookie is not a noodle: " + n);
    }

    @Test
    void aWordNoMenuHasFindsNothingInAnyScope() throws Exception {
        seeds.load();
        for (String type : new String[]{null, "dish", "craving"}) {
            JsonNode res = search("injera", type);
            assertEquals(0, res.get("hits").size(), "type=" + type);
            assertEquals(0, res.get("total").asInt());
        }
    }

    @Test
    void aCravingSentenceHasNoFoodWordSoTheDishFilterDoesNotBreakIt() throws Exception {
        seeds.load();
        // "but" and "also" join the flavors, they are not food a dish must contain
        assertEquals(names(search("something sweet but also spicy", null)), names(search("something sweet but also spicy", "dish")));
        assertFalse(search("something sweet but also spicy", "dish").get("hits").isEmpty());
    }

    @Test
    void theTypeParameterIsForgivingAndCaseInsensitive() throws Exception {
        seeds.load();
        List<String> plain = names(search("ramen", null));
        assertEquals(names(search("ramen", "dish")), names(search("ramen", "Dish")));
        assertEquals(names(search("ramen", "dish")), names(search("ramen", "dishes")));
        assertEquals(plain, names(search("ramen", "nonsense")), "an unknown type means everything");
        assertEquals(plain, names(search("ramen", "")));
    }

    @Test
    void scopeParsing() {
        assertEquals(Scope.ALL, Scope.fromParam(null));
        assertEquals(Scope.DISH, Scope.fromParam(" DISH "));
        assertEquals(Scope.DISH, Scope.fromParam("dishes"));
        assertEquals(Scope.CRAVING, Scope.fromParam("Craving"));
        assertEquals(Scope.CRAVING, Scope.fromParam("cravings"));
        assertEquals(Scope.ALL, Scope.fromParam("restaurants"), "restaurants are not a dish search; the app filters those itself");
    }

    @Test
    void everyHitCarriesItsRestaurantsCuisineForTheCardToShow() throws Exception {
        seeds.load();
        JsonNode res = search("pasta", null);
        assertFalse(res.get("hits").isEmpty());
        for (JsonNode h : res.get("hits")) {
            assertTrue(h.hasNonNull("cuisine") && !h.get("cuisine").asText().isBlank(), h.get("name").asText() + " has no cuisine");
        }
        for (JsonNode h : res.get("hits")) assertTrue(h.get("cuisine").asText().contains("Italian"), "pasta comes from Italian kitchens here: " + h.get("cuisine").asText());
        List<String> cuisines = new ArrayList<>();
        res.get("hits").forEach(h -> cuisines.add(h.get("cuisine").asText()));
        assertTrue(cuisines.contains("Italian, American, Comfort Food") || cuisines.contains("Italian"), "as the owner wrote it, not reformatted: " + cuisines);
    }
}
