package com.example.zomato.search;

import com.example.zomato.entity.SearchEvent;
import com.example.zomato.repository.SearchClickRepository;
import com.example.zomato.repository.SearchEventRepository;
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

import java.time.LocalDateTime;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * The admin's demand-gaps view: cravings that found nothing, grouped by cuisine next to how many restaurants serve it.
 * The seeded restaurants declare Italian, Japanese, Mexican, Thai, American and Indian food; nobody serves Korean or Ethiopian.
 */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:demand_gaps;DB_CLOSE_DELAY=-1;MODE=PostgreSQL")
@AutoConfigureMockMvc
@Import(DemandGapIntegrationTest.Cfg.class)
class DemandGapIntegrationTest {

    @TestConfiguration
    static class Cfg {
        @Bean
        @Primary
        EmbeddingProvider none() { return new NoEmbeddingProvider(); }
    }

    @Autowired MockMvc mvc;
    @Autowired SeedDishLoader seeds;
    @Autowired SearchEventRepository events;
    @Autowired SearchClickRepository clicks;
    @Autowired JwtService jwt;
    private final ObjectMapper json = new ObjectMapper();

    private String admin() { return "Bearer " + jwt.generateToken("admin@cravey.com", "ADMIN"); }

    @BeforeEach
    void setUp() {
        seeds.load();
        clicks.deleteAll();
        events.deleteAll();
    }

    @AfterEach
    void tidy() {
        clicks.deleteAll();
        events.deleteAll();
    }

    /** {@code searchers} different people each search {@code query} once, {@code daysAgo} days back, and find nothing. */
    private void unmet(String query, int searchers, int daysAgo) { unmet(query, null, searchers, daysAgo, true, false); }

    private void unmet(String query, String flavors, int searchers, int daysAgo, boolean unmet, boolean superseded) {
        for (int i = 0; i < searchers; i++) one(query, flavors, "p" + i + "-" + daysAgo, daysAgo, unmet, superseded);
    }

    private void one(String query, String flavors, String searcher, int daysAgo, boolean unmet, boolean superseded) {
        SearchEvent e = new SearchEvent();
        e.setPublicId(UUID.randomUUID().toString());
        e.setCreatedAt(LocalDateTime.now().minusDays(daysAgo).withHour(12));
        e.setNormalizedQuery(query);
        e.setFlavors(flavors);
        e.setSessionKey(searcher);
        e.setUnmet(unmet);
        e.setSuperseded(superseded);
        events.save(e);
    }

    private JsonNode report(String query) throws Exception {
        return json.readTree(mvc.perform(get("/admin/search/demand-gaps" + query).header("Authorization", admin()))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
    }

    private JsonNode group(JsonNode r, String cuisine) {
        for (JsonNode g : r.get("groups")) if (g.get("cuisine").asText().equals(cuisine)) return g;
        return null;
    }

    private JsonNode gap(JsonNode group, String key) {
        for (JsonNode g : group.get("gaps")) if (g.get("key").asText().equals(key)) return g;
        return null;
    }

    @Test
    void aCuisineNobodyServesIsAHoleInTheSupply() throws Exception {
        unmet("injera", 6, 1);
        JsonNode eth = group(report(""), "ethiopian");
        assertNotNull(eth);
        assertEquals("NO_RESTAURANT", eth.get("status").asText());
        assertEquals(0, eth.get("restaurantsServing").asInt());
        assertEquals(6, eth.get("searcherDays").asInt());
        assertEquals("injera", eth.get("gaps").get(0).get("examples").get(0).asText());
    }

    @Test
    void aServedCuisineWithUnmetCravingsIsADishGap() throws Exception {
        unmet("ramen", 7, 2);
        JsonNode jp = group(report(""), "japanese");
        assertEquals("DISH_GAP", jp.get("status").asText());
        assertEquals(1, jp.get("restaurantsServing").asInt());
        assertTrue(jp.get("openRestaurantsServing").asInt() <= jp.get("restaurantsServing").asInt());
    }

    @Test
    void aFusionIsListedUnderEachOfItsCuisines() throws Exception {
        unmet("kimchi carbonara", 8, 1);
        JsonNode r = report("");
        JsonNode korean = group(r, "korean"), italian = group(r, "italian");
        assertEquals("NO_RESTAURANT", korean.get("status").asText());
        assertEquals("DISH_GAP", italian.get("status").asText());
        JsonNode g = gap(korean, "fusion:italian+korean");
        assertEquals("FUSION", g.get("kind").asText());
        assertEquals(8, g.get("searcherDays").asInt());
        assertEquals("italian", g.get("alsoCuisines").get(0).asText());
        assertEquals("korean", gap(italian, "fusion:italian+korean").get("alsoCuisines").get(0).asText());
    }

    @Test
    void cravingsWithNoCuisineGoInTheirOwnGroupWithNoSupplyFigure() throws Exception {
        unmet("sweet spicy", "sweet,spicy", 6, 1, true, false);
        JsonNode other = group(report(""), "other");
        assertEquals("NO_CUISINE", other.get("status").asText());
        assertTrue(other.get("restaurantsServing").isNull());
        assertEquals("FLAVOR", other.get("gaps").get(0).get("kind").asText());
    }

    @Test
    void differentWordingsOfTheSameCravingAreOneGap() throws Exception {
        unmet("jollof rice", 3, 1);
        unmet("rice jollof", 3, 2);
        JsonNode g = gap(group(report(""), "west-african"), "dish:jollof+rice");
        assertNotNull(g);
        assertEquals(6, g.get("searcherDays").asInt());
        assertEquals(2, g.get("examples").size());
    }

    // ------------------------------------------------------------------ nothing rests on one person

    @Test
    void oneOrTwoPeopleAreNotAPatternAndTheFloorCannotBeLowered() throws Exception {
        unmet("ceviche", 2, 1);
        JsonNode r = report("");
        assertNull(group(r, "peruvian"));
        assertEquals(1, r.get("phrasesBelowMinimum").asInt());
        r = report("?min=1");
        assertNull(group(r, "peruvian"), "asking for min=1 is raised to 3");
        assertEquals(3, r.get("minSearcherDays").asInt());
        assertNull(group(report("?min=2"), "peruvian"), "min=2 is also raised to 3");
    }

    @Test
    void oneKeenPersonSearchingTwentyTimesCountsOnce() throws Exception {
        for (int i = 0; i < 20; i++) one("tagine", null, "same-person", 1, true, false);
        JsonNode r = report("");
        assertNull(group(r, "moroccan"));
        assertEquals(20, r.get("unmetSearches").asInt());
        assertEquals(1, r.get("phrasesBelowMinimum").asInt());
    }

    @Test
    void thePersonCountsOncePerDayAcrossDays() throws Exception {
        for (int d = 1; d <= 3; d++) one("pho", null, "returning-" + d, d, true, false);
        JsonNode g = gap(group(report("?min=3"), "vietnamese"), "dish:pho");
        assertEquals(3, g.get("searcherDays").asInt());
        assertEquals(3, g.get("activeDays").asInt());
    }

    // ------------------------------------------------------------------ what is not counted

    @Test
    void servedSearchesPartialQueriesAndOldSearchesAreIgnored() throws Exception {
        unmet("injera", null, 6, 1, false, false);   // found something
        unmet("injera", null, 6, 1, true, true);     // typed on, replaced by a longer query
        unmet("injera", 6, 40);                      // outside the window
        JsonNode r = report("");
        assertNull(group(r, "ethiopian"));
        assertEquals(0, r.get("unmetSearches").asInt());
        assertNotNull(group(report("?days=60"), "ethiopian"), "a longer window sees the old searches");
    }

    @Test
    void simulatedTrafficIsIgnoredWhenSimulationIsOff() throws Exception {
        for (int i = 0; i < 6; i++) {
            SearchEvent e = new SearchEvent();
            e.setPublicId(UUID.randomUUID().toString());
            e.setCreatedAt(LocalDateTime.now().minusDays(1));
            e.setNormalizedQuery("injera");
            e.setSessionKey("sim" + i);
            e.setUnmet(true);
            e.setSimulated(true);
            events.save(e);
        }
        assertNull(group(report(""), "ethiopian"));
    }

    @Test
    void biggestGapsComeFirst() throws Exception {
        unmet("injera", 5, 1);
        unmet("kimchi carbonara", 9, 1);
        unmet("ramen", 7, 1);
        JsonNode r = report("");
        int previous = Integer.MAX_VALUE;
        for (JsonNode g : r.get("groups")) {
            assertTrue(g.get("searcherDays").asInt() <= previous);
            previous = g.get("searcherDays").asInt();
        }
        assertEquals(3, r.get("phrasesShown").asInt());
    }

    @Test
    void anEmptyLogGivesAnEmptyReport() throws Exception {
        JsonNode r = report("");
        assertEquals(0, r.get("groups").size());
        assertEquals(0, r.get("unmetSearches").asInt());
    }

    @Test
    void onlyAnAdminMayAskAndNoPersonalDataIsReturned() throws Exception {
        mvc.perform(get("/admin/search/demand-gaps")).andExpect(status().is4xxClientError());
        mvc.perform(get("/admin/search/demand-gaps").header("Authorization", "Bearer " + jwt.generateToken("o@cravey.com", "OWNER"))).andExpect(status().isForbidden());
        mvc.perform(get("/admin/search/demand-gaps").header("Authorization", "Bearer " + jwt.generateToken("c@cravey.com", "CUSTOMER"))).andExpect(status().isForbidden());
        unmet("injera", 6, 1);
        String body = mvc.perform(get("/admin/search/demand-gaps").header("Authorization", admin())).andReturn().getResponse().getContentAsString();
        assertFalse(body.contains("p0-1"), "no searcher key appears");
        assertFalse(body.toLowerCase().contains("session"));
    }
}
