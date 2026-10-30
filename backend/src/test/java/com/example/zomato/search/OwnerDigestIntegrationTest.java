package com.example.zomato.search;

import com.example.zomato.entity.Notification;
import com.example.zomato.entity.Restaurant;
import com.example.zomato.entity.RestaurantOwner;
import com.example.zomato.entity.SearchAttributionDaily;
import com.example.zomato.entity.SearchTrend;
import com.example.zomato.entity.User;
import com.example.zomato.repository.NotificationRepository;
import com.example.zomato.repository.RestaurantOwnerRepository;
import com.example.zomato.repository.RestaurantRepository;
import com.example.zomato.repository.SearchAttributionDailyRepository;
import com.example.zomato.repository.SearchTrendRepository;
import com.example.zomato.repository.UserRepository;
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
import java.util.Date;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** The weekly owner digest: who gets one, when, what it says, and when it stays quiet. */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:owner_digest;DB_CLOSE_DELAY=-1;MODE=PostgreSQL")
@AutoConfigureMockMvc
@Import(OwnerDigestIntegrationTest.Cfg.class)
class OwnerDigestIntegrationTest {

    @TestConfiguration
    static class Cfg {
        @Bean
        @Primary
        EmbeddingProvider none() { return new NoEmbeddingProvider(); }
    }

    private static final String A = "digest.a@cravey.test";
    private static final String B = "digest.b@cravey.test";

    @Autowired MockMvc mvc;
    @Autowired SeedDishLoader seeds;
    @Autowired OwnerDigestService digest;
    @Autowired RestaurantRepository restaurants;
    @Autowired RestaurantOwnerRepository owners;
    @Autowired UserRepository users;
    @Autowired NotificationRepository notifications;
    @Autowired SearchTrendRepository trendRows;
    @Autowired SearchAttributionDailyRepository attributionRows;
    @Autowired com.example.zomato.repository.LocationRepository locations;
    @Autowired JwtService jwt;
    private final ObjectMapper json = new ObjectMapper();

    private User userA;
    private Restaurant casa;

    @BeforeEach
    void setUp() {
        seeds.load();
        notifications.deleteAll();
        trendRows.deleteAll();
        attributionRows.deleteAll();
        for (Restaurant r : restaurants.findAll()) if (r.getOwner() != null) { r.setOwner(null); restaurants.save(r); }
        RestaurantOwner a = owner("Owner A", A);
        casa = restaurants.findAll().stream().filter(r -> r.getName().equals("Casa Fuego")).findFirst().orElseThrow();
        casa.setOwner(a);
        restaurants.save(casa);
        userA = users.findFirstByEmailIgnoreCase(A).orElseGet(() -> users.save(new User("Owner A", A, "OWNER")));
    }

    @AfterEach
    void tidy() {
        notifications.deleteAll();
        trendRows.deleteAll();
        attributionRows.deleteAll();
    }

    private RestaurantOwner owner(String name, String email) {
        return owners.findByEmailIgnoreCase(email).stream().findFirst().orElseGet(() -> owners.save(new RestaurantOwner(name, email, "1")));
    }

    private void rising(String label, String area) {
        SearchTrend t = new SearchTrend();
        t.setRunDate(LocalDate.now());
        t.setPhraseKey("dish:" + label.toLowerCase().replace(' ', '+'));
        t.setKind("DISH");
        t.setLabel(label);
        t.setStatus("RISING");
        t.setGrowth(5);
        t.setRecentSearchers(20);
        t.setArea(area);
        trendRows.save(t);
    }

    private List<Notification> digestsOf(User u) {
        return notifications.findByUser_UserId(u.getUserId()).stream().filter(n -> OwnerDigestService.TYPE.equals(n.getType())).toList();
    }

    @Test
    void anOwnerWithSomethingToHearGetsOneShortUnreadDigest() {
        rising("Birria Tacos", null);
        var s = digest.generate(LocalDate.now());
        assertEquals(1, s.sent());
        List<Notification> got = digestsOf(userA);
        assertEquals(1, got.size());
        Notification n = got.get(0);
        assertFalse(n.isRead());
        assertTrue(n.getMessage().contains("Birria Tacos"), n.getMessage());
        assertTrue(n.getMessage().contains("Insights"), "points to where the detail is");
        assertTrue(n.getMessage().length() <= 255, "fits the message column");
    }

    @Test
    void nobodyGetsTwoInAWeekButTheNextWeekStartsAgain() {
        rising("Birria Tacos", null);
        digest.generate(LocalDate.now());
        var again = digest.generate(LocalDate.now());
        assertEquals(0, again.sent());
        assertEquals(1, again.alreadySentThisWeek());
        assertEquals(1, digestsOf(userA).size());

        Notification old = digestsOf(userA).get(0);
        old.setTimestamp(new Date(System.currentTimeMillis() - 8L * 24 * 3600 * 1000));
        notifications.save(old);
        assertEquals(1, digest.generate(LocalDate.now()).sent());
        assertEquals(2, digestsOf(userA).size());
    }

    @Test
    void aWeekWithNothingToSaySendsNothing() {
        var s = digest.generate(LocalDate.now());
        assertEquals(0, s.sent());
        assertEquals(1, s.nothingToSay());
        assertTrue(digestsOf(userA).isEmpty());
    }

    @Test
    void anOwnerWithoutAnAccountCannotBeNotifiedAndIsCounted() {
        RestaurantOwner b = owner("Owner B", B);
        Restaurant bella = restaurants.findAll().stream().filter(r -> r.getName().equals("Bella Napoli")).findFirst().orElseThrow();
        bella.setOwner(b);
        restaurants.save(bella);
        rising("Birria Tacos", null);
        var s = digest.generate(LocalDate.now());
        assertEquals(2, s.owners());
        assertEquals(1, s.sent());
        assertEquals(1, s.noAccount());
    }

    @Test
    void restaurantsWithNoOwnerAreSkipped() {
        casa.setOwner(null);
        restaurants.save(casa);
        rising("Birria Tacos", null);
        var s = digest.generate(LocalDate.now());
        assertEquals(0, s.owners());
        assertEquals(0, notifications.count());
    }

    @Test
    void whatIsRisingNearTheOwnerComesFirst() {
        casa.getLocation().setCity("Oakland");
        locations.save(casa.getLocation());
        rising("Pad Thai", null);
        rising("Birria Tacos", "oakland");
        rising("Ramen", "san francisco");
        digest.generate(LocalDate.now());
        String m = digestsOf(userA).get(0).getMessage();
        assertTrue(m.contains("rising near you: Birria Tacos"), m);
        assertFalse(m.contains("Ramen") || m.contains("Pad Thai"), "another city's trend and the general one are not repeated: " + m);
    }

    @Test
    void ordersFromSearchAreCountedForTheLastWeekOnlyAndOnlyForTheOwnersRestaurants() {
        SearchAttributionDaily mine = new SearchAttributionDaily(LocalDate.now().minusDays(2), "dish:birria+tacos", casa.getId(), 1, false);
        mine.add(4, 6, 1500);
        attributionRows.save(mine);
        SearchAttributionDaily old = new SearchAttributionDaily(LocalDate.now().minusDays(20), "dish:birria+tacos", casa.getId(), 1, false);
        old.add(50, 60, 99999);
        attributionRows.save(old);
        Restaurant other = restaurants.findAll().stream().filter(r -> !r.getName().equals("Casa Fuego")).findFirst().orElseThrow();
        SearchAttributionDaily theirs = new SearchAttributionDaily(LocalDate.now().minusDays(1), "dish:pad+thai", other.getId(), 2, false);
        theirs.add(30, 30, 77777);
        attributionRows.save(theirs);

        digest.generate(LocalDate.now());
        String m = digestsOf(userA).get(0).getMessage();
        assertTrue(m.contains("4 orders from search (₹1500)"), m);
    }

    @Test
    void theMessageNeverOverflowsEvenWithAVeryLongPhraseLabel() {
        rising("x".repeat(195), null);   // the trend label column holds 200
        digest.generate(LocalDate.now());
        String m = digestsOf(userA).get(0).getMessage();
        assertEquals(250, m.length(), "cut to the limit, not rejected");
        assertTrue(m.endsWith("…"));
    }

    @Test
    void onlyAnAdminCanTriggerItAndTheAnswerHoldsCountsNotText() throws Exception {
        rising("Birria Tacos", null);
        mvc.perform(post("/admin/search/digest/generate")).andExpect(status().is4xxClientError());
        mvc.perform(post("/admin/search/digest/generate").header("Authorization", "Bearer " + jwt.generateToken(A, "OWNER"))).andExpect(status().isForbidden());
        JsonNode r = json.readTree(mvc.perform(post("/admin/search/digest/generate").header("Authorization", "Bearer " + jwt.generateToken("admin@cravey.com", "ADMIN")))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        assertEquals(1, r.get("sent").asInt());
        assertFalse(r.toString().contains("Birria"));
    }
}
