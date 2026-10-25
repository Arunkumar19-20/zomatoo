package com.example.zomato.search;

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
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** The nightly trend job and its admin endpoints, over simulated traffic with known answers. Keyword mode keeps it model-free. */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:trend_job;DB_CLOSE_DELAY=-1;MODE=PostgreSQL")
@AutoConfigureMockMvc
@Import(TrendJobIntegrationTest.Cfg.class)
class TrendJobIntegrationTest {

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
    @Autowired SearchEventRepository events;
    @Autowired SearchClickRepository clicks;
    @Autowired SearchTrendRepository trendRows;
    @Autowired SearchProperties props;
    @Autowired JwtService jwt;
    private final ObjectMapper json = new ObjectMapper();

    private String admin() { return "Bearer " + jwt.generateToken("admin@cravey.com", "ADMIN"); }
    private String owner() { return "Bearer " + jwt.generateToken("owner@cravey.com", "OWNER"); }

    @BeforeEach
    void seed() {
        seeds.load();
        trendRows.deleteAll();
        clicks.deleteAll();
        events.deleteAll();
    }

    @AfterEach
    void tidy() {
        props.setSimEnabled(false);
        clicks.deleteAll();
        events.deleteAll();
        trendRows.deleteAll();
    }

    private List<String> keys(String status) throws Exception {
        JsonNode arr = json.readTree(mvc.perform(get("/admin/search/trends").param("status", status).header("Authorization", admin()))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        List<String> out = new ArrayList<>();
        arr.forEach(n -> out.add(n.get("key").asText()));
        return out;
    }

    @Test
    void simulationIsOffByDefaultAndAdminOnly() throws Exception {
        mvc.perform(post("/admin/search/simulate")).andExpect(status().is4xxClientError());
        mvc.perform(post("/admin/search/simulate").header("Authorization", owner())).andExpect(status().isForbidden());
        mvc.perform(post("/admin/search/simulate").header("Authorization", admin())).andExpect(status().isForbidden());
        assertEquals(0, events.count());
    }

    @Test
    void plantedTrendsAreFoundThroughTheEndpoints() throws Exception {
        props.setSimEnabled(true);
        mvc.perform(post("/admin/search/simulate").param("days", "35").header("Authorization", admin())).andExpect(status().isOk());
        JsonNode run = json.readTree(mvc.perform(post("/admin/search/trends/run").header("Authorization", admin()))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        assertEquals(2, run.get("byStatus").get("RISING").asInt(), run.toString());

        List<String> rising = keys("RISING");
        assertEquals(2, rising.size(), rising.toString());
        assertTrue(rising.contains("fusion:italian+korean"), rising.toString());
        assertTrue(rising.stream().anyMatch(k -> k.contains("birria")), rising.toString());
        assertEquals(List.of("dish:chocolate+dubai"), keys("FLUKE"));
        assertTrue(keys("STEADY").contains("dish:pizza"));
    }

    @Test
    void rerunningTheSameDayReplacesTheSnapshot() throws Exception {
        props.setSimEnabled(true);
        simulator.generate(35, 7);
        trends.run(LocalDate.now());
        long first = trendRows.count();
        trends.run(LocalDate.now());
        assertEquals(first, trendRows.count());
        assertEquals(1, trendRows.findAll().stream().map(t -> t.getRunDate()).distinct().count());
    }

    @Test
    void simulatedTrafficIsIgnoredUnlessSimulationIsOn() throws Exception {
        props.setSimEnabled(true);
        simulator.generate(35, 7);
        props.setSimEnabled(false);
        var run = trends.run(LocalDate.now());
        assertEquals(0, run.searchesRead());
        assertTrue(trends.latest(null).isEmpty());
    }

    @Test
    void clearingTheSimulationRemovesOnlySimulatedRows() throws Exception {
        props.setSimEnabled(true);
        // a real customer search stays
        mvc.perform(get("/search/dishes").param("q", "tiramisu").header("X-Search-Client", "real-customer")).andExpect(status().isOk());
        long real = events.count();
        simulator.generate(10, 7);
        assertTrue(events.count() > real);
        mvc.perform(delete("/admin/search/simulate").header("Authorization", admin())).andExpect(status().isOk());
        assertEquals(real, events.count());
        assertTrue(events.findAll().stream().noneMatch(e -> e.isSimulated()));
    }

    @Test
    void trendEndpointsAreAdminOnly() throws Exception {
        mvc.perform(get("/admin/search/trends")).andExpect(status().is4xxClientError());
        mvc.perform(get("/admin/search/trends").header("Authorization", owner())).andExpect(status().isForbidden());
        mvc.perform(post("/admin/search/trends/run").header("Authorization", owner())).andExpect(status().isForbidden());
    }

    @Test
    void aRealBurstOfSearchesFromRealRequestsIsCountedByPeopleNotRequests() throws Exception {
        // one person hammering a query, and eight different people searching it, today only
        for (int i = 0; i < 30; i++) mvc.perform(get("/search/dishes").param("q", "tteokbokki").header("X-Search-Client", "hammer")).andExpect(status().isOk());
        for (int i = 0; i < 8; i++) mvc.perform(get("/search/dishes").param("q", "tteokbokki").header("X-Search-Client", "person-" + i)).andExpect(status().isOk());
        var run = trends.run(LocalDate.now());
        var t = trends.latest(null).stream().filter(v -> v.key().contains("tteokbokki")).findFirst().orElseThrow();
        assertEquals(9, t.recentSearchers(), "one hammering person plus eight others is nine searchers");
        assertEquals("FLUKE", t.status(), "all on one day: not a trend yet");
        assertTrue(run.searchesRead() >= 38);
    }
}
