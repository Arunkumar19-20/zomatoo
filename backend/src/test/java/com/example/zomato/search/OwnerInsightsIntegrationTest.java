package com.example.zomato.search;

import com.example.zomato.entity.MenuItem;
import com.example.zomato.entity.Restaurant;
import com.example.zomato.entity.RestaurantOwner;
import com.example.zomato.entity.SearchTrend;
import com.example.zomato.repository.DropRepository;
import com.example.zomato.repository.MenuItemRepository;
import com.example.zomato.repository.OwnerSuggestionRepository;
import com.example.zomato.repository.RestaurantOwnerRepository;
import com.example.zomato.repository.RestaurantRepository;
import com.example.zomato.repository.SearchClickRepository;
import com.example.zomato.repository.SearchEventRepository;
import com.example.zomato.repository.SearchTrendRepository;
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
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** The owner Insights endpoints and the customer chips, over hand-made rising phrases and the demo catalog (keyword mode). */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:owner_insights;DB_CLOSE_DELAY=-1;MODE=PostgreSQL")
@AutoConfigureMockMvc
@Import(OwnerInsightsIntegrationTest.Cfg.class)
class OwnerInsightsIntegrationTest {

    @TestConfiguration
    static class Cfg {
        @Bean
        @Primary
        EmbeddingProvider none() { return new NoEmbeddingProvider(); }
    }

    @Autowired MockMvc mvc;
    @Autowired SeedDishLoader seeds;
    @Autowired SuggestionService service;
    @Autowired SearchIndexService index;
    @Autowired OwnerSuggestionRepository suggestionRows;
    @Autowired SearchTrendRepository trendRows;
    @Autowired SearchEventRepository events;
    @Autowired SearchClickRepository clicks;
    @Autowired RestaurantRepository restaurants;
    @Autowired RestaurantOwnerRepository owners;
    @Autowired MenuItemRepository items;
    @Autowired DropRepository drops;
    @Autowired JwtService jwt;
    private final ObjectMapper json = new ObjectMapper();
    private static final String CASA_OWNER = "casa.owner@cravey.test";
    private static final String BELLA_OWNER = "bella.owner@cravey.test";

    private String token(String email, String role) { return "Bearer " + jwt.generateToken(email, role); }

    @BeforeEach
    void fresh() {
        seeds.load();
        suggestionRows.deleteAll();
        trendRows.deleteAll();
        clicks.deleteAll();
        events.deleteAll();
        for (Restaurant r : restaurants.findAll()) {
            if (r.getOwner() != null) { r.setOwner(null); restaurants.save(r); }
        }
        own("Casa Fuego", CASA_OWNER);
        own("Bella Napoli", BELLA_OWNER);
        for (MenuItem i : items.findAll()) {
            if (!Boolean.TRUE.equals(i.getIsAvailable())) { i.setIsAvailable(true); items.save(i); index.onChanged(i); }
        }
    }

    private void own(String restaurant, String email) {
        RestaurantOwner o = owners.findByEmailIgnoreCase(email).stream().findFirst().orElseGet(() -> owners.save(new RestaurantOwner("Owner " + email, email, "0000000000")));
        Restaurant r = restaurants.findAll().stream().filter(x -> x.getName().equals(restaurant)).findFirst().orElseThrow();
        r.setOwner(o);
        restaurants.save(r);
    }

    private void rising(String kind, String key, String label, String cuisines, int searchers, double growth, double unmet, String samples) {
        SearchTrend t = new SearchTrend();
        t.setRunDate(LocalDate.now());
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

    private void plant() {
        rising("DISH", "dish:birria+taco", "Birria Taco", "mexican", 38, 20, 0.0, "birria tacos|birria taco");
        rising("FUSION", "fusion:italian+korean", "Italian × Korean fusion", "italian,korean", 120, 22, 1.0, "kimchi carbonara|bulgogi pizza");
        service.generate(LocalDate.now());
    }

    private JsonNode fetch(String url, String auth) throws Exception {
        var req = get(url);
        if (auth != null) req.header("Authorization", auth);
        return json.readTree(mvc.perform(req).andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
    }

    private long suggestionIdFor(String ownerEmail, String type) throws Exception {
        for (JsonNode s : fetch("/owner/insights", token(ownerEmail, "OWNER")).get("suggestions")) if (s.get("type").asText().equals(type)) return s.get("id").asLong();
        throw new AssertionError("no " + type + " suggestion for " + ownerEmail);
    }

    // ------------------------------------------------------------------ owner insights

    @Test
    void ownersSeeOnlyTheirOwnRestaurantsSuggestions() throws Exception {
        plant();
        JsonNode casa = fetch("/owner/insights", token(CASA_OWNER, "OWNER"));
        assertEquals(1, casa.get("restaurants").size());
        assertEquals("Casa Fuego", casa.get("restaurants").get(0).get("name").asText());
        assertEquals(1, casa.get("suggestions").size());
        assertEquals("MAKE_DROP", casa.get("suggestions").get(0).get("type").asText());
        assertEquals("Casa Fuego", casa.get("suggestions").get(0).get("restaurantName").asText());

        JsonNode bella = fetch("/owner/insights", token(BELLA_OWNER, "OWNER"));
        assertEquals(1, bella.get("suggestions").size());
        assertEquals("ADD_DISH", bella.get("suggestions").get(0).get("type").asText());
        assertEquals("Kimchi Carbonara", bella.get("suggestions").get(0).get("payload").get("suggestedName").asText());

        assertEquals(2, casa.get("rising").size(), "the market view is shared");
        assertTrue(casa.get("rising").get(0).has("recentSearchers"), "owners get the numbers customers do not");
    }

    @Test
    void anOwnerWithNoRestaurantsGetsNothingAndAdminsGetEverything() throws Exception {
        plant();
        JsonNode stranger = fetch("/owner/insights", token("nobody@cravey.test", "OWNER"));
        assertEquals(0, stranger.get("restaurants").size());
        assertEquals(0, stranger.get("suggestions").size());
        JsonNode admin = fetch("/owner/insights", token("admin@cravey.com", "ADMIN"));
        assertTrue(admin.get("restaurants").size() >= 8);
        assertTrue(admin.get("suggestions").size() >= 2);
    }

    @Test
    void customersAndVisitorsAreKeptOut() throws Exception {
        mvc.perform(get("/owner/insights")).andExpect(status().isUnauthorized());
        mvc.perform(get("/owner/insights").header("Authorization", token("customer@cravey.com", "CUSTOMER"))).andExpect(status().isForbidden());
        mvc.perform(post("/owner/insights/1/dismiss").header("Authorization", token("customer@cravey.com", "CUSTOMER"))).andExpect(status().isForbidden());
    }

    @Test
    void anOwnerCannotTouchAnotherRestaurantsSuggestion() throws Exception {
        plant();
        long casaDrop = suggestionIdFor(CASA_OWNER, "MAKE_DROP");
        for (String action : List.of("dismiss", "snooze", "acted", "drop")) {
            mvc.perform(post("/owner/insights/" + casaDrop + "/" + action).contentType(MediaType.APPLICATION_JSON).content("{}")
                    .header("Authorization", token(BELLA_OWNER, "OWNER"))).andExpect(status().isNotFound());
        }
        mvc.perform(post("/owner/insights/999999/dismiss").header("Authorization", token(BELLA_OWNER, "OWNER"))).andExpect(status().isNotFound());
        assertEquals(1, fetch("/owner/insights", token(CASA_OWNER, "OWNER")).get("suggestions").size(), "still there, untouched");
        assertEquals(0, drops.findAll().stream().filter(d -> "Beef Birria Tacos Drop".equals(d.getTitle())).count());
    }

    @Test
    void dismissSnoozeAndActedRemoveItFromTheOpenList() throws Exception {
        plant();
        for (String action : List.of("dismiss", "snooze", "acted")) {
            suggestionRows.deleteAll();
            service.generate(LocalDate.now());
            long id = suggestionIdFor(CASA_OWNER, "MAKE_DROP");
            JsonNode r = json.readTree(mvc.perform(post("/owner/insights/" + id + "/" + action).header("Authorization", token(CASA_OWNER, "OWNER")))
                    .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
            assertEquals(switch (action) { case "dismiss" -> "DISMISSED"; case "snooze" -> "SNOOZED"; default -> "ACTED"; }, r.get("status").asText());
            assertEquals(0, fetch("/owner/insights", token(CASA_OWNER, "OWNER")).get("suggestions").size());
        }
    }

    @Test
    void creatingTheSuggestedDropUsesTheSuggestionsRestaurantAndDishAndClosesIt() throws Exception {
        plant();
        long id = suggestionIdFor(CASA_OWNER, "MAKE_DROP");
        long before = drops.count();
        JsonNode drop = json.readTree(mvc.perform(post("/owner/insights/" + id + "/drop").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"totalSlots\":25,\"title\":\"Birria night\"}").header("Authorization", token(CASA_OWNER, "OWNER")))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        assertEquals(before + 1, drops.count());
        assertEquals("Birria night", drop.get("title").asText());
        assertEquals(25, drop.get("totalSlots").asInt());
        assertEquals(idOf("Casa Fuego"), drop.get("restaurantId").asInt());
        assertTrue(drop.get("price").asDouble() > 0);
        assertEquals(0, fetch("/owner/insights", token(CASA_OWNER, "OWNER")).get("suggestions").size(), "closed after use");
        mvc.perform(post("/owner/insights/" + id + "/drop").header("Authorization", token(CASA_OWNER, "OWNER"))).andExpect(status().isNotFound());
    }

    @Test
    void dropRequestsAreBoundedAndOnlyForDropSuggestions() throws Exception {
        plant();
        long dropsBefore = drops.count();
        long id = suggestionIdFor(CASA_OWNER, "MAKE_DROP");
        for (String bad : List.of("{\"totalSlots\":0}", "{\"totalSlots\":201}", "{\"totalSlots\":-5}")) {
            mvc.perform(post("/owner/insights/" + id + "/drop").contentType(MediaType.APPLICATION_JSON).content(bad).header("Authorization", token(CASA_OWNER, "OWNER")))
                    .andExpect(status().isBadRequest());
        }
        long addDish = suggestionIdFor(BELLA_OWNER, "ADD_DISH");
        mvc.perform(post("/owner/insights/" + addDish + "/drop").header("Authorization", token(BELLA_OWNER, "OWNER"))).andExpect(status().isNotFound());
        assertEquals(dropsBefore, drops.count(), "no Drop was created by any of the rejected requests");
    }

    private int idOf(String name) { return restaurants.findAll().stream().filter(r -> r.getName().equals(name)).findFirst().orElseThrow().getId(); }

    // ------------------------------------------------------------------ customer chips

    @Test
    void chipsShowOnlyRisingPhrasesSomeoneCanOrderAndNeverTheNumbers() throws Exception {
        plant();   // birria is on a menu; the Korean x Italian fusion is on none
        mvc.perform(get("/search/trending")).andExpect(status().isOk());
        JsonNode chips = fetch("/search/trending", null);
        assertEquals(1, chips.size(), chips.toString());
        JsonNode c = chips.get(0);
        assertEquals("Birria Taco", c.get("label").asText());
        assertTrue(c.get("dishCount").asInt() >= 1);
        Set<String> fields = new HashSet<>();
        c.fieldNames().forEachRemaining(fields::add);
        assertEquals(Set.of("label", "query", "kind", "dishCount"), fields, "no searcher counts, growth or unmet share for customers");
    }

    @Test
    void tappingAChipAlwaysFindsTheDish() throws Exception {
        rising("DISH", "dish:birria+taco", "Birria Taco", "mexican", 38, 20, 0.0, "birria tacos");
        rising("FLAVOR", "flavor:spicy+sweet", "Spicy + Sweet", "", 30, 5, 0.0, "sweet and spicy");
        JsonNode chips = fetch("/search/trending", null);
        assertEquals(2, chips.size());
        for (JsonNode c : chips) {
            JsonNode res = fetch("/search/dishes?k=5&q=" + java.net.URLEncoder.encode(c.get("query").asText(), "UTF-8"), null);
            assertTrue(res.get("hits").size() > 0, "chip '" + c.get("label").asText() + "' searched '" + c.get("query").asText() + "' and found nothing");
        }
        List<String> labels = new ArrayList<>();
        chips.forEach(c -> labels.add(c.get("label").asText()));
        assertTrue(labels.contains("Spicy + Sweet"));
    }

    @Test
    void aChipDisappearsWhenTheDishIsSwitchedOff() throws Exception {
        rising("DISH", "dish:birria+taco", "Birria Taco", "mexican", 38, 20, 0.0, "birria tacos");
        assertEquals(1, fetch("/search/trending", null).size());
        MenuItem birria = items.findAll().stream().filter(i -> i.getName().toLowerCase().contains("birria")).findFirst().orElseThrow();
        birria.setIsAvailable(false);
        items.save(birria);
        index.onChanged(birria);
        assertEquals(0, fetch("/search/trending", null).size(), "nobody can order it, so it is not a chip");
    }

    @Test
    void chipsAreCappedAndEmptyWithoutTrends() throws Exception {
        assertEquals(0, fetch("/search/trending", null).size());
        String[][] dishes = {{"pizza", "italian"}, {"burger", "american"}, {"ramen", "japanese"}, {"biryani", "indian"}, {"taco", "mexican"}};
        int g = 10;
        for (String[] d : dishes) rising("DISH", "dish:" + d[0], d[0], d[1], 20, g--, 0.0, d[0]);
        assertEquals(2, fetch("/search/trending?limit=2", null).size());
        assertTrue(fetch("/search/trending?limit=999", null).size() <= TrendingService.MAX_CHIPS);
        assertEquals("pizza", fetch("/search/trending?limit=1", null).get(0).get("label").asText(), "fastest riser first");
    }
}
