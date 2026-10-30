package com.example.zomato.search;

import com.example.zomato.entity.Restaurant;
import com.example.zomato.entity.RestaurantOwner;
import com.example.zomato.entity.SearchEvent;
import com.example.zomato.repository.RestaurantOwnerRepository;
import com.example.zomato.repository.RestaurantRepository;
import com.example.zomato.repository.SearchClickRepository;
import com.example.zomato.repository.SearchEventRepository;
import com.example.zomato.repository.SearchTrendRepository;
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
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Trends per area: a phrase rising among people searching from Oakland is a trend for Oakland even when the rest of the country has not noticed,
 * and an area with too few searchers of its own gets no rows at all. Birria tacos rise only in Oakland, pad thai only in San Francisco.
 */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:area_trends;DB_CLOSE_DELAY=-1;MODE=PostgreSQL")
@AutoConfigureMockMvc
@Import(AreaTrendsIntegrationTest.Cfg.class)
class AreaTrendsIntegrationTest {

    @TestConfiguration
    static class Cfg {
        @Bean
        @Primary
        EmbeddingProvider none() { return new NoEmbeddingProvider(); }
    }

    @Autowired MockMvc mvc;
    @Autowired SeedDishLoader seeds;
    @Autowired TrendService trends;
    @Autowired SearchEventRepository events;
    @Autowired SearchClickRepository clicks;
    @Autowired SearchTrendRepository trendRows;
    @Autowired RestaurantRepository restaurants;
    @Autowired RestaurantOwnerRepository owners;
    @Autowired com.example.zomato.repository.LocationRepository locations;
    @Autowired JwtService jwt;
    private final ObjectMapper json = new ObjectMapper();

    private int seq;
    private static final String OWNER = "area.owner@cravey.test";

    private String admin() { return "Bearer " + jwt.generateToken("admin@cravey.com", "ADMIN"); }

    @BeforeEach
    void setUp() {
        seeds.load();
        trendRows.deleteAll();
        clicks.deleteAll();
        events.deleteAll();
        plant("birria tacos", "oakland", 3);        // rising in Oakland only
        plant("pad thai", "san francisco", 3);      // rising in San Francisco only
        plant("pizza", "san francisco", 1, true);   // steady everywhere it is searched
        plant("pizza", "oakland", 1, true);
        // a small town where only three people ever search for anything
        for (int i = 0; i < 3; i++) one("birria tacos", "tinyville", "tiny-" + i, 1);
        // searches that gave no area still count for everyone
        for (int d = 0; d < 7; d++) for (int i = 0; i < 2; i++) one("ramen", null, "na-" + d + "-" + i, d);
        trends.run(LocalDate.now());
    }

    @AfterEach
    void tidy() {
        trendRows.deleteAll();
        clicks.deleteAll();
        events.deleteAll();
    }

    /** {@code perDay} different people search {@code query} on each of the last 7 days; before that only one person every third day. */
    private void plant(String query, String area, int perDay) { plant(query, area, perDay, false); }

    private void plant(String query, String area, int perDay, boolean steady) {
        for (int d = 0; d < 7; d++) for (int i = 0; i < perDay; i++) one(query, area, area + "-" + query + "-" + d + "-" + i, d);
        for (int d = 7; d < 35; d++) {
            if (steady) for (int i = 0; i < perDay; i++) one(query, area, area + "-" + query + "-b" + d + "-" + i, d);
            else if (d % 3 == 0) one(query, area, area + "-" + query + "-b" + d, d);
        }
    }

    private void one(String query, String area, String searcher, int daysAgo) {
        SearchEvent e = new SearchEvent();
        e.setPublicId(UUID.randomUUID().toString());
        e.setCreatedAt(LocalDateTime.now().minusDays(daysAgo).withHour(12));
        e.setNormalizedQuery(query);
        e.setSessionKey("s" + (seq++)); // every planted search is a different person (the column holds 16 characters)
        e.setArea(area);
        events.save(e);
    }

    /** Trends as the admin sees them; {@code area} null means no area filter. */
    private List<String> keys(String status, String area) throws Exception {
        var req = get("/admin/search/trends").header("Authorization", admin());
        if (status != null) req = req.param("status", status);
        if (area != null) req = req.param("area", area);
        JsonNode arr = json.readTree(mvc.perform(req).andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        List<String> out = new ArrayList<>();
        arr.forEach(n -> out.add(n.get("key").asText()));
        return out;
    }

    private boolean anyContains(List<String> keys, String word) { return keys.stream().anyMatch(k -> k.contains(word)); }

    @Test
    void aPhraseRisingInOneAreaIsATrendForThatAreaOnly() throws Exception {
        List<String> oakland = keys("RISING", "oakland");
        List<String> sf = keys("RISING", "san francisco");
        assertTrue(anyContains(oakland, "birria"), oakland.toString());
        assertFalse(anyContains(oakland, "thai"), oakland.toString());
        assertTrue(anyContains(sf, "thai"), sf.toString());
        assertFalse(anyContains(sf, "birria"), sf.toString());
    }

    @Test
    void theTrendAcrossEveryoneIsStillThereAndHoldsNoAreaRows() throws Exception {
        List<String> everyone = keys("RISING", null);
        assertTrue(anyContains(everyone, "birria") && anyContains(everyone, "thai"), everyone.toString());
        assertTrue(trends.latest(null).stream().allMatch(t -> t.area() == null));
        long globalRows = trendRows.findAll().stream().filter(t -> t.getArea() == null).count();
        assertTrue(globalRows > 0 && trendRows.count() > globalRows, "area rows are stored next to the global ones");
        // one day's snapshot per area and phrase: running again replaces, never doubles
        long before = trendRows.count();
        trends.run(LocalDate.now());
        assertEquals(before, trendRows.count());
    }

    @Test
    void anAreaWithTooFewSearchersOfItsOwnGetsNothing() throws Exception {
        assertTrue(keys(null, "tinyville").isEmpty());
        assertTrue(trendRows.findAll().stream().noneMatch(t -> "tinyville".equals(t.getArea())));
    }

    @Test
    void searchesWithNoAreaCountForEveryoneButBelongToNoArea() throws Exception {
        assertTrue(anyContains(keys("RISING", null), "ramen"), "14 searchers over a week, nothing before");
        assertTrue(trendRows.findAll().stream().filter(t -> t.getPhraseKey().contains("ramen")).allMatch(t -> t.getArea() == null));
    }

    @Test
    void areaNamesAreMatchedWithoutCareForCaseOrSpaces() throws Exception {
        assertTrue(anyContains(keys("RISING", "OAKLAND"), "birria"));
        assertTrue(anyContains(keys("RISING", "  Oakland "), "birria"));
        assertTrue(keys("RISING", "nowhere").isEmpty());
    }

    @Test
    void customerChipsPutWhatIsRisingNearThemFirstThenWhatIsRisingEverywhere() throws Exception {
        List<String> oakland = chipQueries("oakland");
        List<String> sf = chipQueries("San Francisco");
        List<String> nowhere = chipQueries("nowhere");
        assertFalse(oakland.isEmpty());
        assertTrue(oakland.get(0).toLowerCase().contains("birria"), oakland.toString());
        assertTrue(sf.get(0).toLowerCase().contains("thai"), sf.toString());
        assertEquals(oakland.size(), sf.size(), "same phrases, different order: the rest fill in from everyone's trends");
        assertEquals(chipQueries(null), nowhere, "an area with nothing of its own sees the usual chips");
    }

    private List<String> chipQueries(String area) throws Exception {
        var req = get("/search/trending").param("limit", "6");
        if (area != null) req = req.param("area", area);
        JsonNode arr = json.readTree(mvc.perform(req).andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        List<String> out = new ArrayList<>();
        arr.forEach(n -> out.add(n.get("query").asText()));
        return out;
    }

    @Test
    void anOwnerSeesWhatIsRisingInTheirRestaurantsCityMarkedWithIt() throws Exception {
        RestaurantOwner o = owners.findByEmailIgnoreCase(OWNER).stream().findFirst().orElseGet(() -> owners.save(new RestaurantOwner("Area Owner", OWNER, "1")));
        for (Restaurant r : restaurants.findAll()) if (r.getOwner() != null) { r.setOwner(null); restaurants.save(r); }
        Restaurant casa = restaurants.findAll().stream().filter(r -> r.getName().equals("Casa Fuego")).findFirst().orElseThrow();
        casa.setOwner(o);
        casa.getLocation().setCity("Oakland");
        locations.save(casa.getLocation());
        restaurants.save(casa);
        JsonNode rising = json.readTree(mvc.perform(get("/owner/insights").header("Authorization", "Bearer " + jwt.generateToken(OWNER, "OWNER")))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).get("rising");
        JsonNode first = rising.get(0);
        assertTrue(first.get("label").asText().toLowerCase().contains("birria"), rising.toString());
        assertEquals("oakland", first.get("area").asText());
        boolean thaiGlobal = false;
        for (JsonNode r : rising) if (r.get("label").asText().toLowerCase().contains("thai")) thaiGlobal = r.get("area").isNull();
        assertTrue(thaiGlobal, "what is rising elsewhere still shows, not marked with this city");
        long birriaRows = 0;
        for (JsonNode r : rising) if (r.get("label").asText().toLowerCase().contains("birria")) birriaRows++;
        assertEquals(1, birriaRows, "a phrase rising locally and everywhere is listed once, as local");
    }
}
