package com.example.zomato.config;

import com.example.zomato.entity.User;
import com.example.zomato.repository.MenuItemRepository;
import com.example.zomato.repository.UserRepository;
import com.example.zomato.security.JwtService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * The app's "Quick Demo Sign-In" signs in as made-up people with a token it mints itself. Against a fresh database those people did not exist,
 * so cart and checkout worked until Place Order answered "User not found". In the demo profile the accounts now exist.
 */
@SpringBootTest(properties = {"spring.profiles.active=demo", "spring.datasource.url=jdbc:h2:mem:demo_accounts;DB_CLOSE_DELAY=-1;MODE=PostgreSQL",
        "stripe.secret-key=sk_test_demo", "stripe.public-key=pk_test_demo", "stripe.webhook-secret=whsec_demo"})
@AutoConfigureMockMvc
class DemoAccountsSeedTest {

    private static final List<String> EMAILS = List.of("aarav.sharma@gmail.com", "arunkumar2006.d@gmail.com", "rahul.singh@gmail.com", "admin1@zomato.com");

    @Autowired UserRepository users;
    @Autowired MenuItemRepository menu;
    @Autowired MockMvc mvc;
    @Autowired JwtService jwt;
    private final ObjectMapper json = new ObjectMapper();

    @Test
    void theDemoButtonsAccountsExistVerifiedAndWithNoPasswordAnyoneKnows() throws Exception {
        for (String email : EMAILS) {
            User u = users.findByEmail(email).orElseThrow(() -> new AssertionError(email + " is missing"));
            assertTrue(u.getEmailVerified(), email);
            mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                    .content("{\"email\":\"" + email + "\",\"password\":\"Password123!\"}")).andExpect(status().is4xxClientError());
        }
        assertEquals("CUSTOMER", users.findByEmail("aarav.sharma@gmail.com").orElseThrow().getRole());
    }

    @Test
    void theDemoCustomerCanAddToCartAndPlaceAnOrder() throws Exception {
        String token = "Bearer " + jwt.generateToken("aarav.sharma@gmail.com", "CUSTOMER");
        int item = menu.findAll().get(0).getId();
        mvc.perform(post("/cart/items").contentType(MediaType.APPLICATION_JSON).content("{\"menuItemId\":" + item + ",\"quantity\":1}").header("Authorization", token))
                .andExpect(status().isOk());
        JsonNode order = json.readTree(mvc.perform(post("/orders/checkout").contentType(MediaType.APPLICATION_JSON).content("{}").header("Authorization", token))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        assertEquals("aarav.sharma@gmail.com", order.get("customerEmail").asText());
        assertTrue(order.get("totalAmount").asDouble() > 0);
    }

    @Test
    void seedingTwiceDoesNotDuplicateAnyone() {
        long before = users.count();
        seeder.run();   // what a restart does
        assertEquals(before, users.count());
    }

    @Autowired DataInitializer seeder;
}
