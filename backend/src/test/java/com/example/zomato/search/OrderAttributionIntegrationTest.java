package com.example.zomato.search;

import com.example.zomato.entity.CartItem;
import com.example.zomato.entity.Order;
import com.example.zomato.entity.PaymentStatus;
import com.example.zomato.entity.SearchAttributionDaily;
import com.example.zomato.repository.CartItemRepository;
import com.example.zomato.repository.CartRepository;
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

/** Search to cart to order to delivery, and what is (and is not) remembered along the way. Keyword mode keeps it model-free. */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:order_attribution;DB_CLOSE_DELAY=-1;MODE=PostgreSQL")
@AutoConfigureMockMvc
@Import(OrderAttributionIntegrationTest.Cfg.class)
class OrderAttributionIntegrationTest {

    @TestConfiguration
    static class Cfg {
        @Bean
        @Primary
        EmbeddingProvider none() { return new NoEmbeddingProvider(); }
    }

    @Autowired MockMvc mvc;
    @Autowired SeedDishLoader seeds;
    @Autowired OrderService orderService;
    @Autowired OrderAttributionService attribution;
    @Autowired OrderRepository orders;
    @Autowired CartRepository carts;
    @Autowired CartItemRepository cartItems;
    @Autowired OrderAttributionPendingRepository pending;
    @Autowired SearchAttributionDailyRepository daily;
    @Autowired SearchEventRepository events;
    @Autowired SearchClickRepository clicks;
    @Autowired RestaurantRepository restaurants;
    @Autowired UserRepository users;
    @Autowired JwtService jwt;
    private final ObjectMapper json = new ObjectMapper();
    private static final String ME = "hungry@cravey.test";

    @BeforeEach
    void fresh() {
        seeds.load();
        pending.deleteAll();
        daily.deleteAll();
        clicks.deleteAll();
        events.deleteAll();
        carts.findAll().forEach(c -> cartItems.deleteByCartId(c.getId()));
    }

    private JsonNode search(String q, String client) throws Exception {
        MockHttpServletRequestBuilder req = get("/search/dishes").param("q", q).param("k", "5");
        if (client != null) req.header("X-Search-Client", client);
        return json.readTree(mvc.perform(req).andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
    }

    private void addToCart(String email, int itemId, String searchId, Integer rank, String client, String dnt) throws Exception {
        if (users.findByEmail(email).isEmpty()) {
            var u = new com.example.zomato.entity.User("Test " + email, email, "CUSTOMER");
            u.setEmailVerified(true);   // checkout is refused for unverified accounts
            users.save(u);
        }
        String body = "{\"menuItemId\":" + itemId + ",\"quantity\":1" + (searchId == null ? "" : ",\"searchId\":\"" + searchId + "\",\"searchRank\":" + (rank == null ? 1 : rank)) + "}";
        MockHttpServletRequestBuilder req = post("/cart/items").contentType(MediaType.APPLICATION_JSON).content(body)
                .header("Authorization", "Bearer " + jwt.generateToken(email, "CUSTOMER"));
        if (client != null) req.header("X-Search-Client", client);
        if (dnt != null) req.header("DNT", dnt);
        String res = mvc.perform(req).andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        assertFalse(res.contains("attribution") || res.contains("dish:"), "the cart response must not echo the phrase: " + res);
    }

    /** Finds the first shown dish of a search that sits in a given restaurant. */
    private int shownItem(JsonNode res, String restaurant) {
        for (JsonNode h : res.get("hits")) if (h.get("restaurantName").asText().equals(restaurant)) return h.get("itemId").asInt();
        throw new AssertionError("no " + restaurant + " dish in " + res);
    }

    private Order checkoutAndDeliver(String email, int restaurantId, String status, PaymentStatus pay) {
        Order o = orderService.checkout(email, restaurantId);
        o.setStatus(status);
        o.setPaymentStatus(pay);
        return orders.save(o);
    }

    private int idOf(String restaurant) { return restaurants.findAll().stream().filter(r -> r.getName().equals(restaurant)).findFirst().orElseThrow().getId(); }

    private List<CartItem> myCart() {
        return carts.findAll().stream().flatMap(c -> cartItems.findByCartId(c.getId()).stream()).toList();
    }

    // ------------------------------------------------------------------ the happy path

    @Test
    void aDeliveredOrderFromASearchBecomesAnAnonymousCount() throws Exception {
        JsonNode res = search("birria tacos", "client-1");
        int item = shownItem(res, "Casa Fuego");
        addToCart(ME, item, res.get("searchId").asText(), 1, "client-1", null);

        CartItem inCart = myCart().get(0);
        assertEquals("dish:birria+taco", inCart.getSearchAttribution(), "the cart remembers the phrase, not the query");
        assertNotNull(inCart.getSearchAttributionAt());

        Order order = orderService.checkout(ME, idOf("Casa Fuego"));
        assertEquals(1, pending.findByOrderId(order.getOrderId()).size(), "held until the order is settled");
        assertEquals(0, daily.count(), "nothing is counted before delivery");

        assertEquals(0, attribution.settle().counted(), "still placed and unpaid: waiting");
        assertEquals(1, pending.count());

        order.setPaymentStatus(PaymentStatus.PAID);
        order.setStatus("DELIVERED");
        orders.save(order);
        var summary = attribution.settle();
        assertEquals(1, summary.counted());

        assertEquals(0, pending.count(), "the link between order and phrase is gone once counted");
        SearchAttributionDaily row = daily.findAll().get(0);
        assertEquals("dish:birria+taco", row.getPhraseKey());
        assertEquals(item, row.getItemId());
        assertEquals(idOf("Casa Fuego"), row.getRestaurantId());
        assertEquals(1, row.getOrders());
        assertEquals(1, row.getUnits());
        assertTrue(row.getRevenue() > 0);
        assertEquals(LocalDate.now(), row.getOrderDay());
    }

    @Test
    void theCountsHoldNothingThatCouldFindAnOrderOrAPerson() {
        Set<String> banned = Set.of("orderid", "customerid", "customer", "email", "userid", "user", "searchid", "searcheventid", "sessionkey", "rawquery", "query", "clientid", "ip");
        for (Field f : SearchAttributionDaily.class.getDeclaredFields()) {
            assertFalse(banned.contains(f.getName().toLowerCase()), "the daily counts must not store " + f.getName());
        }
    }

    @Test
    void severalOrdersOfTheSameDishAddUpAndUnitsDoNotInflateTheOrderCount() throws Exception {
        for (int i = 0; i < 2; i++) {
            JsonNode res = search("birria tacos", "client-" + i);
            int item = shownItem(res, "Casa Fuego");
            String email = "buyer" + i + "@cravey.test";
            addToCart(email, item, res.get("searchId").asText(), 1, "client-" + i, null);
            if (i == 0) addToCart(email, item, res.get("searchId").asText(), 1, "client-" + i, null);   // two units in one order
            checkoutAndDeliver(email, idOf("Casa Fuego"), "DELIVERED", PaymentStatus.PAID);
        }
        assertEquals(2, attribution.settle().counted());
        SearchAttributionDaily row = daily.findAll().get(0);
        assertEquals(1, daily.count());
        assertEquals(2, row.getOrders(), "two orders");
        assertEquals(3, row.getUnits(), "three units");
    }

    // ------------------------------------------------------------------ what is not attributed

    @Test
    void anAddThatDoesNotCheckOutIsNotAttributed() throws Exception {
        JsonNode res = search("birria tacos", "client-1");
        int shown = shownItem(res, "Casa Fuego");
        String id = res.get("searchId").asText();
        int notShown = 1;
        while (res.toString().contains("\"itemId\":" + notShown + ",") || res.toString().contains("\"itemId\":" + notShown + "}")) notShown++;

        addToCart("a@cravey.test", shown, id, 1, "someone-else", null);       // a different searcher
        addToCart("b@cravey.test", notShown, id, 1, "client-1", null);        // a dish that search never showed
        addToCart("c@cravey.test", shown, id, 1, "client-1", "1");            // do not track
        addToCart("d@cravey.test", shown, null, null, "client-1", null);      // no search at all
        addToCart("e@cravey.test", shown, "00000000-0000-0000-0000-000000000000", 1, "client-1", null);   // a search that does not exist
        assertTrue(myCart().stream().allMatch(c -> c.getSearchAttribution() == null), "none of those may be remembered");
    }

    @Test
    void aMoodSearchHasNoPhraseSoNothingIsRemembered() throws Exception {
        JsonNode res = search("late night snack", "client-1");
        addToCart(ME, res.get("hits").get(0).get("itemId").asInt(), res.get("searchId").asText(), 1, "client-1", null);
        assertNull(myCart().get(0).getSearchAttribution());
    }

    @Test
    void cancelledRefundedAndStaleOrdersAreDiscardedNotCounted() throws Exception {
        String[] who = {"cancel@cravey.test", "refund@cravey.test", "stale@cravey.test"};
        Order[] os = new Order[3];
        for (int i = 0; i < 3; i++) {
            JsonNode res = search("birria tacos", "client-" + i);
            addToCart(who[i], shownItem(res, "Casa Fuego"), res.get("searchId").asText(), 1, "client-" + i, null);
            os[i] = orderService.checkout(who[i], idOf("Casa Fuego"));
        }
        os[0].setStatus("CANCELLED");
        os[1].setStatus("DELIVERED");
        os[1].setPaymentStatus(PaymentStatus.REFUNDED);
        orders.save(os[0]);
        orders.save(os[1]);
        pending.findByOrderId(os[2].getOrderId()).forEach(p -> { p.setCreatedAt(LocalDateTime.now().minusDays(4)); pending.save(p); });

        var summary = attribution.settle();
        assertEquals(0, summary.counted());
        assertEquals(3, summary.discarded());
        assertEquals(0, pending.count());
        assertEquals(0, daily.count());
    }

    @Test
    void anAttributionOlderThanADayIsNotCarriedIntoTheOrderAndIsForgottenAtNight() throws Exception {
        JsonNode res = search("birria tacos", "client-1");
        addToCart(ME, shownItem(res, "Casa Fuego"), res.get("searchId").asText(), 1, "client-1", null);
        myCart().forEach(c -> { c.setSearchAttributionAt(LocalDateTime.now().minusHours(25)); cartItems.save(c); });

        Order order = orderService.checkout(ME, idOf("Casa Fuego"));
        assertEquals(0, pending.findByOrderId(order.getOrderId()).size(), "too old to say the search led to the order");

        addToCart("other@cravey.test", shownItem(res, "Casa Fuego"), res.get("searchId").asText(), 1, "client-1", null);
        myCart().forEach(c -> { c.setSearchAttributionAt(LocalDateTime.now().minusHours(30)); cartItems.save(c); });
        attribution.nightlyPurge();
        assertTrue(myCart().stream().allMatch(c -> c.getSearchAttribution() == null && c.getSearchAttributionAt() == null), "old cart attributions are cleared");
    }

    @Test
    void settlingTwiceCountsAnOrderOnce() throws Exception {
        JsonNode res = search("birria tacos", "client-1");
        addToCart(ME, shownItem(res, "Casa Fuego"), res.get("searchId").asText(), 1, "client-1", null);
        checkoutAndDeliver(ME, idOf("Casa Fuego"), "DELIVERED", PaymentStatus.PAID);
        attribution.settle();
        attribution.settle();
        assertEquals(1, daily.findAll().get(0).getOrders());
    }

    @Test
    void anOrderWithNoSearchBehindItLeavesNoTrace() throws Exception {
        JsonNode res = search("birria tacos", "client-1");
        addToCart(ME, shownItem(res, "Casa Fuego"), null, null, null, null);
        Order o = checkoutAndDeliver(ME, idOf("Casa Fuego"), "DELIVERED", PaymentStatus.PAID);
        assertEquals(0, pending.findByOrderId(o.getOrderId()).size());
        assertEquals(0, attribution.settle().counted());
    }

    @Test
    void settlingByHandIsAdminOnly() throws Exception {
        mvc.perform(post("/admin/search/attribution/settle")).andExpect(status().isUnauthorized());
        mvc.perform(post("/admin/search/attribution/settle").header("Authorization", "Bearer " + jwt.generateToken("owner@cravey.com", "OWNER"))).andExpect(status().isForbidden());
        mvc.perform(post("/admin/search/attribution/settle").header("Authorization", "Bearer " + jwt.generateToken("admin@cravey.com", "ADMIN"))).andExpect(status().isOk());
    }
}
