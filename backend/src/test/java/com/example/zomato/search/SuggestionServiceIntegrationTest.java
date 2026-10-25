package com.example.zomato.search;

import com.example.zomato.entity.OwnerSuggestion;
import com.example.zomato.entity.Restaurant;
import com.example.zomato.entity.RestaurantOwner;
import com.example.zomato.entity.SearchTrend;
import com.example.zomato.repository.OwnerSuggestionRepository;
import com.example.zomato.repository.RestaurantOwnerRepository;
import com.example.zomato.repository.RestaurantRepository;
import com.example.zomato.repository.SearchClickRepository;
import com.example.zomato.repository.SearchEventRepository;
import com.example.zomato.repository.SearchTrendRepository;
import com.example.zomato.search.SuggestionService.View;
import com.example.zomato.security.JwtService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
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
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Suggestion lifecycle over hand-made rising phrases and the demo catalog (keyword mode, no model). */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:suggestions;DB_CLOSE_DELAY=-1;MODE=PostgreSQL")
@AutoConfigureMockMvc
@Import(SuggestionServiceIntegrationTest.Cfg.class)
class SuggestionServiceIntegrationTest {

    @TestConfiguration
    static class Cfg {
        @Bean
        @Primary
        EmbeddingProvider none() { return new NoEmbeddingProvider(); }
    }

    @Autowired MockMvc mvc;
    @Autowired SeedDishLoader seeds;
    @Autowired SuggestionService service;
    @Autowired OwnerSuggestionRepository rows;
    @Autowired SearchTrendRepository trendRows;
    @Autowired SearchEventRepository events;
    @Autowired SearchClickRepository clicks;
    @Autowired RestaurantRepository restaurants;
    @Autowired RestaurantOwnerRepository owners;
    @Autowired JwtService jwt;
    private final ObjectMapper json = new ObjectMapper();
    private static final LocalDate TODAY = LocalDate.of(2026, 10, 26); // a Monday

    @BeforeEach
    void fresh() {
        seeds.load();
        rows.deleteAll();
        trendRows.deleteAll();
        clicks.deleteAll();
        events.deleteAll();
        for (Restaurant r : restaurants.findAll()) {
            if (r.getOwner() != null) {
                r.setOwner(null);
                restaurants.save(r);
            }
        }
    }

    private void rising(String kind, String key, String label, String cuisines, int searchers, double growth, double unmet, String samples) {
        SearchTrend t = new SearchTrend();
        t.setRunDate(TODAY);
        t.setKind(kind);
        t.setPhraseKey(key);
        t.setLabel(label);
        t.setCuisines(cuisines);
        t.setStatus("RISING");
        t.setReason("test");
        t.setRecentSearchers(searchers);
        t.setBaselineSearchers(4);
        t.setGrowth(growth);
        t.setActiveDays(7);
        t.setTopDayShare(0.2);
        t.setUnmetShare(unmet);
        t.setSamples(samples);
        trendRows.save(t);
    }

    /** Pretends the same phrases are still rising on another day. */
    private void stillRisingOn(LocalDate day) {
        trendRows.findAll().forEach(t -> { t.setRunDate(day); trendRows.save(t); });
    }

    private int idOf(String name) {
        return restaurants.findAll().stream().filter(r -> r.getName().equals(name)).findFirst().orElseThrow().getId();
    }

    private List<View> forRestaurant(String name) { return service.openFor(Set.of(idOf(name))); }

    @Test
    void anUnservedFusionGoesToItalianKitchensWithAPrefilledDish() {
        rising("FUSION", "fusion:italian+korean", "Italian × Korean fusion", "italian,korean", 120, 22, 1.0, "italian korean fusion pasta|kimchi carbonara|bulgogi pizza");
        var summary = service.generate(TODAY);
        assertTrue(summary.created() >= 1);
        View v = forRestaurant("Bella Napoli").get(0);
        assertEquals("ADD_DISH", v.type());
        assertEquals("Kimchi Carbonara", v.payload().suggestedName());
        assertFalse(v.payload().flavorTags().isEmpty());
        assertTrue(v.body().contains("120 people"), v.body());
        assertTrue(forRestaurant("Spice Route").isEmpty(), "an Indian kitchen has no reason to hear about it");
        assertTrue(forRestaurant("Tokyo Ramen House").isEmpty());
    }

    @Test
    void aStrongRiseOfADishARestaurantHasIsADropAndAWeakOneIsStockGuidance() {
        rising("DISH", "dish:birria+taco", "Birria Taco", "mexican", 38, 20, 0.0, "birria tacos|birria taco");
        rising("DISH", "dish:pizza", "Pizza", "italian", 12, 2.4, 0.0, "pizza");
        service.generate(TODAY);

        View drop = forRestaurant("Casa Fuego").stream().filter(v -> v.trendKey().equals("dish:birria+taco")).findFirst().orElseThrow();
        assertEquals("MAKE_DROP", drop.type());
        assertNotNull(drop.payload().dishId());
        assertTrue(drop.payload().suggestedSlots() >= 10 && drop.payload().suggestedSlots() <= 60);
        assertTrue(drop.payload().price() > 0);
        assertEquals(TODAY.plusDays(1).atTime(18, 0).toString(), drop.payload().suggestedStartsAt());

        View stock = forRestaurant("Bella Napoli").stream().filter(v -> v.trendKey().equals("dish:pizza")).findFirst().orElseThrow();
        assertEquals("STOCK_UP", stock.type());
        assertTrue(stock.body().contains("no sales estimate"), "must not promise a sales number it cannot know");
    }

    @Test
    void impressionsAndTapsAreCountedFromRealSearches() throws Exception {
        for (int i = 0; i < 5; i++) mvc.perform(get("/search/dishes").param("q", "pizza").header("X-Search-Client", "p" + i)).andExpect(status().isOk());
        JsonNode tapped = json.readTree(mvc.perform(get("/search/dishes").param("q", "pizza").header("X-Search-Client", "tapper"))
                .andReturn().getResponse().getContentAsString());
        mvc.perform(post("/search/events/" + tapped.get("searchId").asText() + "/click").contentType("application/json").header("X-Search-Client", "tapper")
                .content("{\"itemId\":" + tapped.get("hits").get(0).get("itemId").asInt() + ",\"rank\":1,\"action\":\"OPEN\"}")).andExpect(status().isNoContent());

        // the searches above happened just now, so the phrase has to be rising as of today for the evidence window to include them
        LocalDate today = LocalDate.now();
        rising("DISH", "dish:pizza", "Pizza", "italian", 12, 2.4, 0.0, "pizza");
        trendRows.findAll().forEach(x -> { x.setRunDate(today); trendRows.save(x); });
        service.generate(today);

        View v = service.openFor(Set.of(idOf("Bella Napoli"))).stream().filter(x -> x.trendKey().equals("dish:pizza")).findFirst().orElseThrow();
        assertTrue(v.impressions() >= 6, "six searches for pizza were shown Bella Napoli's pizza: " + v.impressions());
        assertTrue(v.taps() >= 1, "the one tap was counted");
    }

    @Test
    void anOwnerGetsAtMostThreeSuggestionsAWeekAcrossAllTheirRestaurants() {
        RestaurantOwner owner = new RestaurantOwner();
        owner.setOwnerName("Multi Owner");
        owner.setEmail("multi@cravey.test");
        owner.setPhone("0000000000");
        owner = owners.save(owner);
        for (String n : List.of("Bella Napoli", "Casa Fuego", "Smokehouse 66", "Tokyo Ramen House")) {
            Restaurant r = restaurants.findAll().stream().filter(x -> x.getName().equals(n)).findFirst().orElseThrow();
            r.setOwner(owner);
            restaurants.save(r);
        }
        rising("DISH", "dish:pizza", "Pizza", "italian", 30, 3.5, 0.0, "pizza");
        rising("DISH", "dish:taco", "Taco", "mexican", 28, 3.2, 0.0, "tacos");
        rising("DISH", "dish:burger", "Burger", "american", 26, 3.1, 0.0, "burger");
        rising("DISH", "dish:ramen", "Ramen", "japanese", 24, 3.0, 0.0, "ramen");
        rising("FUSION", "fusion:italian+korean", "Italian × Korean fusion", "italian,korean", 120, 22, 1.0, "kimchi carbonara");

        var s = service.generate(TODAY);
        Set<Integer> mine = Set.of(idOf("Bella Napoli"), idOf("Casa Fuego"), idOf("Smokehouse 66"), idOf("Tokyo Ramen House"));
        assertEquals(3, service.openFor(mine).size(), "five matched, three kept: " + s);
        assertEquals(2, s.skippedByCap(), "the other two were held back");

        stillRisingOn(TODAY.plusDays(1));
        var again = service.generate(TODAY.plusDays(1));
        assertEquals(0, again.created(), "same week: no more than three");
        assertEquals(3, service.openFor(mine).size(), "and the same three, refreshed, not duplicated");

        stillRisingOn(TODAY.plusDays(7));
        var nextWeek = service.generate(TODAY.plusDays(7));
        assertTrue(service.openFor(mine).size() > 3, "a new week lets the two held-back ones through: " + nextWeek);
    }

    @Test
    void theBestScoringSuggestionsAreTheOnesKept() {
        RestaurantOwner owner = owners.save(owner("Ranker", "rank@cravey.test"));
        for (String n : List.of("Bella Napoli", "Casa Fuego", "Smokehouse 66", "Tokyo Ramen House")) own(n, owner);
        rising("DISH", "dish:pizza", "Pizza", "italian", 9, 2.1, 0.0, "pizza");
        rising("DISH", "dish:taco", "Taco", "mexican", 10, 2.2, 0.0, "tacos");
        rising("DISH", "dish:burger", "Burger", "american", 11, 2.3, 0.0, "burger");
        rising("DISH", "dish:ramen", "Ramen", "japanese", 12, 2.4, 0.0, "ramen");
        rising("FUSION", "fusion:italian+korean", "Italian × Korean fusion", "italian,korean", 120, 22, 1.0, "kimchi carbonara");
        service.generate(TODAY);
        Set<Integer> mine = Set.of(idOf("Bella Napoli"), idOf("Casa Fuego"), idOf("Smokehouse 66"), idOf("Tokyo Ramen House"));
        Set<String> kept = service.openFor(mine).stream().map(View::trendKey).collect(java.util.stream.Collectors.toSet());
        assertTrue(kept.contains("fusion:italian+korean"), "the biggest, least served demand wins a slot: " + kept);
        assertFalse(kept.contains("dish:pizza"), "the smallest rise is the one dropped: " + kept);
    }

    private RestaurantOwner owner(String name, String email) {
        RestaurantOwner o = new RestaurantOwner();
        o.setOwnerName(name);
        o.setEmail(email);
        o.setPhone("0000000000");
        return o;
    }

    private void own(String restaurant, RestaurantOwner owner) {
        Restaurant r = restaurants.findAll().stream().filter(x -> x.getName().equals(restaurant)).findFirst().orElseThrow();
        r.setOwner(owner);
        restaurants.save(r);
    }

    @Test
    void dismissingHidesItForThirtyDaysAndOnlyTheRestaurantsOwnerCanDoIt() {
        rising("DISH", "dish:birria+taco", "Birria Taco", "mexican", 38, 20, 0.0, "birria tacos");
        service.generate(TODAY);
        View v = forRestaurant("Casa Fuego").get(0);

        assertTrue(service.dismiss(v.id(), Set.of(idOf("Bella Napoli"))).isEmpty(), "another restaurant cannot touch it");
        assertEquals(1, forRestaurant("Casa Fuego").size());

        assertEquals("DISMISSED", service.dismiss(v.id(), Set.of(idOf("Casa Fuego"))).orElseThrow().status());
        assertTrue(forRestaurant("Casa Fuego").isEmpty());
        assertTrue(service.dismiss(v.id(), Set.of(idOf("Casa Fuego"))).isEmpty(), "already dismissed");

        stillRisingOn(TODAY.plusDays(8));
        service.generate(TODAY.plusDays(8));
        assertTrue(forRestaurant("Casa Fuego").isEmpty(), "not resurfaced inside the cool-down");
        assertEquals(1, rows.count());
    }

    @Test
    void snoozingHidesItForAWeekThenItComesBackRefreshed() {
        rising("DISH", "dish:birria+taco", "Birria Taco", "mexican", 38, 20, 0.0, "birria tacos");
        service.generate(TODAY);
        View v = forRestaurant("Casa Fuego").get(0);
        var snoozed = service.snooze(v.id(), Set.of(idOf("Casa Fuego")), TODAY).orElseThrow();
        assertEquals("SNOOZED", snoozed.status());
        assertEquals(TODAY.plusDays(7), snoozed.snoozedUntil());

        stillRisingOn(TODAY.plusDays(3));
        service.generate(TODAY.plusDays(3));
        assertTrue(forRestaurant("Casa Fuego").isEmpty(), "still asleep");

        // the phrase is still rising a week later
        trendRows.deleteAll();
        rising("DISH", "dish:birria+taco", "Birria Taco", "mexican", 55, 25, 0.0, "birria tacos");
        trendRows.findAll().forEach(x -> { x.setRunDate(TODAY.plusDays(7)); trendRows.save(x); });
        service.generate(TODAY.plusDays(7));
        List<View> back = forRestaurant("Casa Fuego");
        assertEquals(1, back.size());
        assertEquals(55, back.get(0).recentSearchers(), "the numbers are fresh");
        assertEquals(1, rows.count(), "revived, not duplicated");
    }

    @Test
    void actingOnASuggestionClosesItAndRerunsRefreshOpenOnesInPlace() {
        rising("DISH", "dish:birria+taco", "Birria Taco", "mexican", 38, 20, 0.0, "birria tacos");
        service.generate(TODAY);
        service.generate(TODAY);
        assertEquals(1, rows.count(), "running twice does not duplicate");
        View v = forRestaurant("Casa Fuego").get(0);
        assertEquals("ACTED", service.markActed(v.id(), Set.of(idOf("Casa Fuego"))).orElseThrow().status());
        assertTrue(forRestaurant("Casa Fuego").isEmpty());
    }

    @Test
    void openSuggestionsForAPhraseThatStoppedRisingExpireAfterAWeek() {
        rising("DISH", "dish:birria+taco", "Birria Taco", "mexican", 38, 20, 0.0, "birria tacos");
        service.generate(TODAY);
        OwnerSuggestion s = rows.findAll().get(0);
        s.setUpdatedAt(LocalDateTime.of(TODAY.minusDays(1), java.time.LocalTime.NOON));
        rows.save(s);
        trendRows.deleteAll();   // nothing is rising any more
        var run = service.generate(TODAY.plusDays(7));
        assertEquals(1, run.expired());
        assertTrue(forRestaurant("Casa Fuego").isEmpty());
    }

    @Test
    void adminEndpointsAreAdminOnly() throws Exception {
        rising("DISH", "dish:birria+taco", "Birria Taco", "mexican", 38, 20, 0.0, "birria tacos");
        String owner = "Bearer " + jwt.generateToken("owner@cravey.com", "OWNER");
        String admin = "Bearer " + jwt.generateToken("admin@cravey.com", "ADMIN");
        mvc.perform(get("/admin/search/suggestions")).andExpect(status().is4xxClientError());
        mvc.perform(get("/admin/search/suggestions").header("Authorization", owner)).andExpect(status().isForbidden());
        mvc.perform(post("/admin/search/suggestions/generate").header("Authorization", owner)).andExpect(status().isForbidden());
        JsonNode run = json.readTree(mvc.perform(post("/admin/search/suggestions/generate").param("asOf", TODAY.toString()).header("Authorization", admin))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        assertEquals(1, run.get("risingTrends").asInt());
        JsonNode list = json.readTree(mvc.perform(get("/admin/search/suggestions").param("status", "NEW").header("Authorization", admin))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        assertTrue(list.size() >= 1);
        assertEquals("MAKE_DROP", list.get(0).get("type").asText());
    }

    @Test
    void nothingRisingMeansNothingSuggested() {
        var run = service.generate(TODAY);
        assertEquals(0, run.created());
        assertEquals(Optional.empty(), service.all(null).stream().findAny());
    }
}
