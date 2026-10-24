package com.example.zomato.search;

import com.example.zomato.entity.SearchEvent;
import com.example.zomato.repository.SearchClickRepository;
import com.example.zomato.repository.SearchEventRepository;
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
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.lang.reflect.Field;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** What the search log records, what it refuses to record, and how clicks are validated. Keyword mode keeps it fast and model-free. */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:search_log;DB_CLOSE_DELAY=-1;MODE=PostgreSQL")
@AutoConfigureMockMvc
@Import(SearchEventLoggingTest.Cfg.class)
class SearchEventLoggingTest {

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
    @Autowired SearchEventService service;
    @Autowired SearchProperties props;
    @Autowired JwtService jwt;
    private final ObjectMapper json = new ObjectMapper();

    @BeforeEach
    void fresh() {
        seeds.load();
        clicks.deleteAll();
        events.deleteAll();
    }

    private JsonNode search(String q, String client) throws Exception {
        MockHttpServletRequestBuilder req = get("/search/dishes").param("q", q).param("k", "5");
        if (client != null) req.header("X-Search-Client", client);
        return json.readTree(mvc.perform(req).andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
    }

    private int click(String searchId, int itemId, String client, String action) throws Exception {
        MockHttpServletRequestBuilder req = post("/search/events/" + searchId + "/click").contentType(MediaType.APPLICATION_JSON)
                .content("{\"itemId\":" + itemId + ",\"rank\":1,\"action\":\"" + action + "\"}");
        if (client != null) req.header("X-Search-Client", client);
        return mvc.perform(req).andReturn().getResponse().getStatus();
    }

    @Test
    void aSearchIsLoggedWithItsAnswerQualityAndReturnsAnId() throws Exception {
        JsonNode res = search("something sweet but also spicy", "client-a");
        assertTrue(res.hasNonNull("searchId"));

        List<SearchEvent> rows = events.findAll();
        assertEquals(1, rows.size());
        SearchEvent e = rows.get(0);
        assertEquals(res.get("searchId").asText(), e.getPublicId());
        assertEquals("something sweet but also spicy", e.getRawQuery());
        assertEquals("KEYWORD", e.getMode());
        assertTrue(e.getFlavors().contains("sweet") && e.getFlavors().contains("spicy"), e.getFlavors());
        assertTrue(e.getRelevantCount() > 0);
        assertFalse(e.isUnmet(), "the demo catalog serves sweet and spicy: " + e.getUnmetBasis());
        assertEquals(5, e.getShownItemIds().split(",").length);
    }

    @Test
    void aCravingNoMenuServesIsFlaggedUnmet() throws Exception {
        search("ethiopian injera", "client-a");
        SearchEvent e = events.findAll().get(0);
        assertTrue(e.isUnmet(), "basis: " + e.getUnmetBasis());
        assertNotNull(e.getUnmetBasis());
    }

    @Test
    void doNotTrackIsHonouredAndSearchStillWorks() throws Exception {
        JsonNode res = json.readTree(mvc.perform(get("/search/dishes").param("q", "creamy and comforting").header("DNT", "1").header("X-Search-Client", "client-a"))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        assertTrue(res.get("hits").size() > 0);
        assertTrue(res.get("searchId") == null || res.get("searchId").isNull());
        assertEquals(0, events.count());
    }

    @Test
    void whenLoggingIsOffNothingIsRecorded() throws Exception {
        boolean before = props.logEnabled();
        try {
            props.setLogEnabled(false);
            JsonNode res = search("crunchy but tangy", "client-a");
            assertTrue(res.get("searchId") == null || res.get("searchId").isNull());
            assertEquals(0, events.count());
        } finally {
            props.setLogEnabled(before);
        }
    }

    @Test
    void theLogHoldsNothingThatIdentifiesAPerson() {
        Set<String> banned = Set.of("email", "userid", "user", "ip", "ipaddress", "phone", "name", "deviceid", "clientid");
        for (Field f : SearchEvent.class.getDeclaredFields()) {
            assertFalse(banned.contains(f.getName().toLowerCase()), "SearchEvent must not store " + f.getName());
        }
    }

    @Test
    void typingInStagesCountsOnce() throws Exception {
        search("sweet", "client-a");
        search("sweet but also spicy", "client-a");
        List<SearchEvent> rows = events.findAll();
        assertEquals(2, rows.size());
        assertEquals(1, rows.stream().filter(r -> !r.isSuperseded()).count(), "only the finished query counts");
        assertTrue(rows.stream().filter(SearchEvent::isSuperseded).allMatch(r -> r.getRawQuery().equals("sweet")));
    }

    @Test
    void differentSearchersWithTheSameQueryAreBothKept() throws Exception {
        search("sweet", "client-a");
        search("sweet but also spicy", "client-b");
        assertEquals(2, events.findAll().stream().filter(r -> !r.isSuperseded()).count());
        assertEquals(2, events.findAll().stream().map(SearchEvent::getSessionKey).distinct().count());
    }

    @Test
    void aClickIsAcceptedOnceForADishTheSearchShowed() throws Exception {
        JsonNode res = search("sweet and spicy", "client-a");
        String id = res.get("searchId").asText();
        int item = res.get("hits").get(0).get("itemId").asInt();

        assertEquals(204, click(id, item, "client-a", "OPEN"));
        assertEquals(204, click(id, item, "client-a", "OPEN"));
        assertEquals(1, clicks.count(), "a repeated tap is not a second click");
        assertEquals(204, click(id, item, "client-a", "ADD_TO_CART"));
        assertEquals(2, clicks.count());
    }

    @Test
    void clicksThatDoNotCheckOutAreIgnoredWithoutLeakingWhy() throws Exception {
        JsonNode res = search("sweet and spicy", "client-a");
        String id = res.get("searchId").asText();
        int item = res.get("hits").get(0).get("itemId").asInt();

        assertEquals(204, click(id, 999999, "client-a", "OPEN"), "a dish that was not shown");
        assertEquals(204, click(id, item, "client-b", "OPEN"), "a different searcher");
        assertEquals(204, click(id, item, "client-a", "DROP_TABLE"), "an unknown action");
        assertEquals(204, click("00000000-0000-0000-0000-000000000000", item, "client-a", "OPEN"), "an unknown search");
        assertEquals(0, clicks.count());
    }

    @Test
    void oldRawQueriesAreDeletedWithTheirClicks() throws Exception {
        JsonNode res = search("sweet and spicy", "client-a");
        click(res.get("searchId").asText(), res.get("hits").get(0).get("itemId").asInt(), "client-a", "OPEN");
        search("creamy and comforting", "client-b");

        SearchEvent old = events.findByPublicId(res.get("searchId").asText()).orElseThrow();
        old.setCreatedAt(LocalDateTime.now().minusDays(props.logRetentionDays() + 1));
        events.save(old);

        assertEquals(1, service.purgeOld());
        assertEquals(1, events.count());
        assertEquals(0, clicks.count());
    }

    @Test
    void summaryIsAdminOnlyAndCountsWhatHappened() throws Exception {
        search("ethiopian injera", "client-a");
        JsonNode ok = search("sweet and spicy", "client-b");
        click(ok.get("searchId").asText(), ok.get("hits").get(0).get("itemId").asInt(), "client-b", "OPEN");

        mvc.perform(get("/admin/search/events/summary")).andExpect(status().is4xxClientError());
        mvc.perform(get("/admin/search/events/summary").header("Authorization", "Bearer " + jwt.generateToken("owner@cravey.com", "OWNER")))
                .andExpect(status().isForbidden());
        JsonNode s = json.readTree(mvc.perform(get("/admin/search/events/summary").header("Authorization", "Bearer " + jwt.generateToken("admin@cravey.com", "ADMIN")))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        assertEquals(2, s.get("searches").asInt());
        assertEquals(2, s.get("searchers").asInt());
        assertEquals(1, s.get("unmet").asInt());
        assertEquals(1, s.get("searchesWithClick").asInt());
        assertEquals(2, s.get("topQueries").size());
    }

    @Test
    void searcherKeysAreStableForADayAndUnlinkableAcrossDays() {
        var ctx = new SearchEventService.Context("client-a", "10.0.0.1", null, false);
        LocalDate d = LocalDate.of(2026, 10, 24);
        assertEquals(service.sessionKey(ctx, d), service.sessionKey(ctx, d));
        assertNotEquals(service.sessionKey(ctx, d), service.sessionKey(ctx, d.plusDays(1)));
        assertNotEquals(service.sessionKey(ctx, d), service.sessionKey(new SearchEventService.Context("client-b", "10.0.0.1", null, false), d));
        assertFalse(service.sessionKey(ctx, d).contains("client-a"));
        // without a client id the address stands in, so web visitors still count once
        var anon = new SearchEventService.Context(null, "10.0.0.1", null, false);
        assertEquals(service.sessionKey(anon, d), service.sessionKey(new SearchEventService.Context("", "10.0.0.1", null, false), d));
    }
}
