package com.example.zomato.search;

import com.example.zomato.entity.Restaurant;
import com.example.zomato.entity.RestaurantOwner;
import com.example.zomato.repository.OwnerSuggestionRepository;
import com.example.zomato.repository.RestaurantOwnerRepository;
import com.example.zomato.repository.RestaurantRepository;
import com.example.zomato.repository.SearchAttributionDailyRepository;
import com.example.zomato.repository.SearchClickRepository;
import com.example.zomato.repository.SearchEventRepository;
import com.example.zomato.repository.SearchTrendRepository;
import com.example.zomato.search.SuggestionService.View;
import com.example.zomato.security.JwtService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDate;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** What estimates the suggestions show, and when they refuse to show one, over simulated traffic with delivered orders. */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:attribution_estimate;DB_CLOSE_DELAY=-1;MODE=PostgreSQL")
@AutoConfigureMockMvc
@Import(AttributionEstimateIntegrationTest.Cfg.class)
class AttributionEstimateIntegrationTest {

    @TestConfiguration
    static class Cfg {
        @Bean
        @Primary
        EmbeddingProvider none() { return new NoEmbeddingProvider(); }
    }

    @Autowired MockMvc mvc;
    @Autowired SeedDishLoader seeds;
    @Autowired SearchLogSimulator simulator;
    @Autowired TrendService trends;
    @Autowired SuggestionService suggestions;
    @Autowired OwnerSuggestionRepository suggestionRows;
    @Autowired SearchTrendRepository trendRows;
    @Autowired SearchAttributionDailyRepository daily;
    @Autowired SearchEventRepository events;
    @Autowired SearchClickRepository clicks;
    @Autowired RestaurantRepository restaurants;
    @Autowired RestaurantOwnerRepository owners;
    @Autowired SearchProperties props;
    @Autowired OrderAttributionService attribution;
    @Autowired JwtService jwt;
    private final ObjectMapper json = new ObjectMapper();

    @BeforeEach
    void fresh() {
        seeds.load();
        suggestionRows.deleteAll();
        trendRows.deleteAll();
        simulator.clear();
        clicks.deleteAll();
        events.deleteAll();
        props.setSimEnabled(true);
        for (Restaurant r : restaurants.findAll()) if (r.getOwner() != null) { r.setOwner(null); restaurants.save(r); }
    }

    @AfterEach
    void tidy() {
        props.setSimEnabled(false);
        simulator.clear();
        suggestionRows.deleteAll();
        trendRows.deleteAll();
    }

    private void run() {
        simulator.generate(35, 7);
        trends.run(LocalDate.now());
        suggestions.generate(LocalDate.now());
    }

    private View birria() {
        return suggestions.all(null).stream().filter(v -> v.trendKey().contains("birria")).findFirst().orElseThrow();
    }

    @Test
    void withCountedOrdersTheDropSuggestionCarriesARealEstimate() {
        run();
        View v = birria();
        assertEquals("MAKE_DROP", v.type());
        assertNotNull(v.payload().estimate(), "simulated delivered orders give enough history: " + v.body());
        var e = v.payload().estimate();
        assertTrue(e.weeklyOrders() >= 1);
        assertTrue(e.ordersObserved() >= SuggestionService.ESTIMATE_MIN_ORDERS);
        assertTrue(e.tapsObserved() >= SuggestionService.ESTIMATE_MIN_TAPS);
        assertTrue(e.weeklyRevenue() > 0);
        assertTrue(v.body().contains("expect about " + e.weeklyOrders()), v.body());
        assertFalse(v.body().contains("No sales estimate"), v.body());
        // the estimate is the counted rate times this week's taps, nothing more
        assertEquals(Math.round(v.taps() * ((double) e.ordersObserved() / e.tapsObserved())), e.weeklyOrders());
    }

    @Test
    void withoutCountedOrdersThereIsNoEstimateAndItSaysSo() {
        simulator.generate(35, 7);
        daily.deleteAll();
        trends.run(LocalDate.now());
        suggestions.generate(LocalDate.now());
        View v = birria();
        assertNull(v.payload().estimate());
        assertTrue(v.body().contains("No sales estimate yet"), v.body());
        assertFalse(v.body().contains("expect about"), v.body());
    }

    @Test
    void anAddDishSuggestionNeverGetsAnEstimateBecauseTheDishDoesNotExistYet() {
        run();
        suggestions.all(null).stream().filter(v -> v.type().equals("ADD_DISH")).forEach(v -> {
            assertNull(v.payload().estimate());
            assertFalse(v.body().contains("expect about"));
        });
    }

    @Test
    void ownersSeeTheOrdersSearchBroughtThemAndOnlyTheirOwn() throws Exception {
        run();
        RestaurantOwner casaOwner = owners.save(new RestaurantOwner("Casa", "casa.owner@cravey.test", "000"));
        Restaurant casa = restaurants.findAll().stream().filter(r -> r.getName().equals("Casa Fuego")).findFirst().orElseThrow();
        casa.setOwner(casaOwner);
        restaurants.save(casa);

        JsonNode mine = json.readTree(mvc.perform(get("/owner/insights").header("Authorization", "Bearer " + jwt.generateToken("casa.owner@cravey.test", "OWNER")))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        JsonNode so = mine.get("searchOrders");
        assertEquals(28, so.get("days").asInt());
        long casaOrders = daily.findAll().stream().filter(a -> a.getRestaurantId() == casa.getId()).mapToLong(a -> a.getOrders()).sum();
        assertTrue(casaOrders > 0);
        assertEquals(casaOrders, so.get("orders").asLong(), "exactly this owner's restaurant, none of the others'");
        for (JsonNode p : so.get("topPhrases")) assertTrue(p.get("orders").asInt() >= OwnerInsightsController.MIN_ORDERS_PER_PHRASE, "a phrase appears only with enough orders: " + p);

        JsonNode stranger = json.readTree(mvc.perform(get("/owner/insights").header("Authorization", "Bearer " + jwt.generateToken("nobody@cravey.test", "OWNER")))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        assertEquals(0, stranger.get("searchOrders").get("orders").asInt());
        assertEquals(0, stranger.get("searchOrders").get("topPhrases").size());
    }

    @Test
    void simulatedCountsAreIgnoredWhenSimulationIsOff() {
        run();
        Set<Integer> everyone = restaurants.findAll().stream().map(Restaurant::getId).collect(java.util.stream.Collectors.toSet());
        LocalDate since = LocalDate.now().minusDays(28);
        assertTrue(attribution.totalsFor(everyone, since).orders() > 0, "simulation on: the simulated orders are read");
        props.setSimEnabled(false);
        assertEquals(0, attribution.totalsFor(everyone, since).orders(), "simulation off: they are invisible, as in production");
    }
}
