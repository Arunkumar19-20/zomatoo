package com.example.zomato.search;

import com.example.zomato.entity.Drop;
import com.example.zomato.entity.DropReservation;
import com.example.zomato.entity.Order;
import com.example.zomato.entity.PaymentStatus;
import com.example.zomato.entity.SearchAttributionDaily;
import com.example.zomato.repository.DropRepository;
import com.example.zomato.repository.DropReservationRepository;
import com.example.zomato.repository.OrderAttributionPendingRepository;
import com.example.zomato.repository.OrderRepository;
import com.example.zomato.repository.RestaurantRepository;
import com.example.zomato.repository.SearchAttributionDailyRepository;
import com.example.zomato.repository.SearchClickRepository;
import com.example.zomato.repository.SearchEventRepository;
import com.example.zomato.repository.UserRepository;
import com.example.zomato.security.JwtService;
import com.example.zomato.services.OrderService;
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
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Search to Drop to order to delivery: a Drop reserved from search results is counted like any other order from search, and nothing more
 * than the phrase is kept on the way. Birria tacos at Casa Fuego have a Drop.
 */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:drop_attribution;DB_CLOSE_DELAY=-1;MODE=PostgreSQL")
@AutoConfigureMockMvc
@Import(DropAttributionIntegrationTest.Cfg.class)
class DropAttributionIntegrationTest {

    @TestConfiguration
    static class Cfg {
        @Bean
        @Primary
        EmbeddingProvider none() { return new NoEmbeddingProvider(); }
    }

    private static final java.util.concurrent.atomic.AtomicInteger SEQ = new java.util.concurrent.atomic.AtomicInteger();
    /** a new customer per test: reserving is rate limited per user */
    private String me;

    @Autowired MockMvc mvc;
    @Autowired SeedDishLoader seeds;
    @Autowired OrderService orderService;
    @Autowired OrderAttributionService attribution;
    @Autowired OrderRepository orders;
    @Autowired DropRepository drops;
    @Autowired DropReservationRepository reservations;
    @Autowired OrderAttributionPendingRepository pending;
    @Autowired SearchAttributionDailyRepository daily;
    @Autowired SearchEventRepository events;
    @Autowired SearchClickRepository clicks;
    @Autowired RestaurantRepository restaurants;
    @Autowired UserRepository users;
    @Autowired JwtService jwt;
    private final ObjectMapper json = new ObjectMapper();

    private Drop drop;
    private int itemId;

    @BeforeEach
    void setUp() throws Exception {
        seeds.load();
        pending.deleteAll();
        daily.deleteAll();
        clicks.deleteAll();
        events.deleteAll();
        reservations.deleteAll();
        drops.deleteAll();
        me = "dropper" + SEQ.incrementAndGet() + "@cravey.test";
        if (users.findByEmail(me).isEmpty()) {
            var u = new com.example.zomato.entity.User("Dropper", me, "CUSTOMER");
            u.setEmailVerified(true);
            users.save(u);
        }
        itemId = shownItem(search("birria tacos", "setup-client"), "Casa Fuego");
        drop = newDrop(itemId, 3);
    }

    private Drop newDrop(Integer menuItemId, int slots) {
        Drop d = new Drop();
        d.setTitle("Birria night");
        d.setPrice(24.5);
        d.setRestaurantId(restaurants.findAll().stream().filter(r -> r.getName().equals("Casa Fuego")).findFirst().orElseThrow().getId());
        d.setMenuItemId(menuItemId);
        d.setStartsAt(LocalDateTime.now().minusHours(1));
        d.setEndsAt(LocalDateTime.now().plusHours(2));
        d.setTotalSlots(slots);
        return drops.save(d);
    }

    private JsonNode search(String q, String client) throws Exception {
        MockHttpServletRequestBuilder req = get("/search/dishes").param("q", q).param("k", "5");
        if (client != null) req.header("X-Search-Client", client);
        return json.readTree(mvc.perform(req).andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
    }

    private int shownItem(JsonNode res, String restaurant) {
        for (JsonNode h : res.get("hits")) if (h.get("restaurantName").asText().equals(restaurant)) return h.get("itemId").asInt();
        throw new AssertionError("no " + restaurant + " dish in " + res);
    }

    private MvcResult reserve(int dropId, String body, String client, String dnt) throws Exception {
        MockHttpServletRequestBuilder req = post("/drops/" + dropId + "/reserve").header("Authorization", "Bearer " + jwt.generateToken(me, "CUSTOMER"));
        if (body != null) req.contentType(MediaType.APPLICATION_JSON).content(body);
        if (client != null) req.header("X-Search-Client", client);
        if (dnt != null) req.header("DNT", dnt);
        return mvc.perform(req).andReturn();
    }

    private String searchBody(JsonNode res) { return "{\"searchId\":\"" + res.get("searchId").asText() + "\",\"searchRank\":1}"; }

    private int reservationId(MvcResult r) throws Exception { return json.readTree(r.getResponse().getContentAsString()).get("reservationId").asInt(); }

    private DropReservation fresh(int id) { return reservations.findById(id).orElseThrow(); }

    // ------------------------------------------------------------------ results show the Drop

    @Test
    void aSearchResultShowsALiveDropOnItsDishWithTheSlotsLeft() throws Exception {
        JsonNode hit = null;
        for (JsonNode h : search("birria tacos", "c").get("hits")) if (h.get("itemId").asInt() == itemId) hit = h;
        JsonNode live = hit.get("liveDrop");
        assertEquals(drop.getId(), live.get("dropId").asInt());
        assertEquals(3, live.get("slotsLeft").asInt());
        assertEquals(24.5, live.get("price").asDouble());
    }

    @Test
    void noBadgeForADropThatIsFullNotStartedOrOver() throws Exception {
        drop.setReservedSlots(3);
        drops.save(drop);
        assertTrue(liveDropOf(itemId).isNull(), "no slot left");
        drop.setReservedSlots(0);
        drop.setStartsAt(LocalDateTime.now().plusHours(1));
        drops.save(drop);
        assertTrue(liveDropOf(itemId).isNull(), "not started");
        drop.setStartsAt(LocalDateTime.now().minusHours(3));
        drop.setEndsAt(LocalDateTime.now().minusHours(1));
        drops.save(drop);
        assertTrue(liveDropOf(itemId).isNull(), "over");
    }

    private JsonNode liveDropOf(int item) throws Exception {
        for (JsonNode h : search("birria tacos", "c").get("hits")) if (h.get("itemId").asInt() == item) return h.get("liveDrop") == null ? json.nullNode() : h.get("liveDrop");
        throw new AssertionError("dish not in results");
    }

    // ------------------------------------------------------------------ the happy path

    @Test
    void aDeliveredPaidDropFromASearchBecomesAnAnonymousCount() throws Exception {
        JsonNode res = search("birria tacos", "client-1");
        MvcResult r = reserve(drop.getId(), searchBody(res), "client-1", null);
        assertEquals(201, r.getResponse().getStatus(), r.getResponse().getContentAsString());
        assertFalse(r.getResponse().getContentAsString().contains("dish:"), "the response must not echo the phrase");
        int rid = reservationId(r);
        assertEquals("dish:birria+taco", fresh(rid).getSearchAttribution(), "the reservation remembers the phrase, not the query or the search id");
        assertNotNull(fresh(rid).getSearchAttributionAt());

        Order order = orderService.checkoutDrop(me, rid);
        var held = pending.findByOrderId(order.getOrderId());
        assertEquals(1, held.size());
        assertEquals(itemId, held.get(0).getItemId());
        assertEquals(24.5, held.get(0).getAmount());
        assertNull(fresh(rid).getSearchAttribution(), "forgotten from the reservation once the order holds it");
        assertEquals(0, daily.count(), "nothing is counted before delivery");

        order = orders.findById(order.getOrderId()).orElseThrow();
        order.setStatus("DELIVERED");
        order.setPaymentStatus(PaymentStatus.PAID);
        orders.save(order);
        assertEquals(1, attribution.settle().counted());

        SearchAttributionDaily row = daily.findAll().get(0);
        assertEquals("dish:birria+taco", row.getPhraseKey());
        assertEquals(1, row.getOrders());
        assertEquals(24.5, row.getRevenue());
        assertEquals(0, pending.count());
    }

    @Test
    void aCancelledDropOrderIsNeverCounted() throws Exception {
        JsonNode res = search("birria tacos", "client-1");
        int rid = reservationId(reserve(drop.getId(), searchBody(res), "client-1", null));
        Order order = orderService.checkoutDrop(me, rid);
        order = orders.findById(order.getOrderId()).orElseThrow();
        order.setStatus("CANCELLED");
        orders.save(order);
        var s = attribution.settle();
        assertEquals(0, s.counted());
        assertEquals(1, s.discarded());
        assertEquals(0, daily.count());
    }

    // ------------------------------------------------------------------ what is never attributed

    @Test
    void aReservationThatDidNotComeFromSearchKeepsNothing() throws Exception {
        int rid = reservationId(reserve(drop.getId(), null, "client-1", null));
        assertNull(fresh(rid).getSearchAttribution());
        Order order = orderService.checkoutDrop(me, rid);
        assertTrue(pending.findByOrderId(order.getOrderId()).isEmpty());
    }

    @Test
    void aSearchFromSomeoneElseOrFromAnotherDishDoesNotCount() throws Exception {
        JsonNode res = search("birria tacos", "client-1");
        int rid = reservationId(reserve(drop.getId(), searchBody(res), "a-different-client", null));
        assertNull(fresh(rid).getSearchAttribution(), "a different searcher");

        // a search that never showed the Drop's dish
        reservations.deleteAll();
        JsonNode other = search("tiramisu", "client-1");
        int rid2 = reservationId(reserve(drop.getId(), searchBody(other), "client-1", null));
        assertNull(fresh(rid2).getSearchAttribution(), "the search did not show the dish");
    }

    @Test
    void doNotTrackStoresNothing() throws Exception {
        JsonNode res = search("birria tacos", "client-1");
        int rid = reservationId(reserve(drop.getId(), searchBody(res), "client-1", "1"));
        assertNull(fresh(rid).getSearchAttribution());
    }

    @Test
    void aMadeUpSearchIdIsIgnoredAndTheReservationStillSucceeds() throws Exception {
        MvcResult r = reserve(drop.getId(), "{\"searchId\":\"not-a-search\",\"searchRank\":1}", "client-1", null);
        assertEquals(201, r.getResponse().getStatus());
        assertNull(fresh(reservationId(r)).getSearchAttribution());
    }

    @Test
    void aDropNotForAMenuDishCannotBeAttributed() throws Exception {
        Drop special = newDrop(null, 3);
        JsonNode res = search("birria tacos", "client-1");
        MvcResult r = reserve(special.getId(), searchBody(res), "client-1", null);
        assertEquals(201, r.getResponse().getStatus());
        assertNull(fresh(reservationId(r)).getSearchAttribution());
    }

    @Test
    void aPhraseOlderThanADayIsNotCountedAndNightlyPurgeForgetsIt() throws Exception {
        JsonNode res = search("birria tacos", "client-1");
        int rid = reservationId(reserve(drop.getId(), searchBody(res), "client-1", null));
        DropReservation r = fresh(rid);
        r.setSearchAttributionAt(LocalDateTime.now().minusHours(25));
        reservations.save(r);

        attribution.nightlyPurge();
        assertNull(fresh(rid).getSearchAttribution(), "forgotten after 24 hours");

        // and if it were still there at checkout, a stale one is not counted
        r = fresh(rid);
        r.setSearchAttribution("dish:birria+taco");
        r.setSearchAttributionAt(LocalDateTime.now().minusHours(25));
        reservations.save(r);
        Order order = orderService.checkoutDrop(me, rid);
        assertTrue(pending.findByOrderId(order.getOrderId()).isEmpty());
        assertNull(fresh(rid).getSearchAttribution());
    }

    @Test
    void reservingTwiceFromSearchStillLeavesOneReservationWithOnePhrase() throws Exception {
        JsonNode res = search("birria tacos", "client-1");
        int first = reservationId(reserve(drop.getId(), searchBody(res), "client-1", null));
        MvcResult again = reserve(drop.getId(), searchBody(res), "client-1", null);
        assertEquals(200, again.getResponse().getStatus(), "idempotent: the same hold comes back");
        assertEquals(first, reservationId(again));
        assertEquals(1, reservations.count());
    }
}
