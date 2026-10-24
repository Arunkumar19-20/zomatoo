package com.example.zomato.search;

import com.example.zomato.entity.MenuCategory;
import com.example.zomato.repository.MenuCategoryRepository;
import com.example.zomato.repository.MenuItemRepository;
import com.example.zomato.security.JwtService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.MethodOrderer;
import org.junit.jupiter.api.Order;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestMethodOrder;
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

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Craving search end to end over HTTP on an isolated H2 database, with a deterministic embedding stand-in. */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:dishsearch_it;DB_CLOSE_DELAY=-1;MODE=PostgreSQL")
@AutoConfigureMockMvc
@Import(DishSearchIntegrationTest.Cfg.class)
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class DishSearchIntegrationTest {

    @TestConfiguration
    static class Cfg {
        @Bean
        @Primary
        EmbeddingProvider testEmbeddings() { return new LexiconEmbeddingProvider(); }
    }

    private static final Set<String> SWEET_AND_SPICY = Set.of("Honey Hot Chicken Tenders", "Mango Habanero Wings",
            "Pineapple Jalapeno Cooler", "Tacos al Pastor", "Chili Chocolate Truffle", "Spicy Ginger Cookie Box",
            "Som Tam Papaya Salad", "Sweet Chili Crispy Chicken");

    @Autowired MockMvc mvc;
    @Autowired JwtService jwt;
    @Autowired SeedDishLoader seeds;
    @Autowired SearchIndexService index;
    @Autowired MenuItemRepository items;
    @Autowired MenuCategoryRepository categories;
    private final ObjectMapper json = new ObjectMapper();

    private JsonNode search(String q) throws Exception {
        MvcResult r = mvc.perform(get("/search/dishes").param("q", q).param("k", "10")).andExpect(status().isOk()).andReturn();
        return json.readTree(r.getResponse().getContentAsString());
    }

    private List<String> names(JsonNode res) {
        List<String> out = new ArrayList<>();
        res.get("hits").forEach(h -> out.add(h.get("name").asText()));
        return out;
    }

    private String ownerToken() { return "Bearer " + jwt.generateToken("owner@cravey.com", "OWNER"); }
    private String adminToken() { return "Bearer " + jwt.generateToken("admin@cravey.com", "ADMIN"); }

    @Test @Order(1)
    @DisplayName("Demo catalog loads once and is searchable")
    void seedsLoadAndIndex() {
        Map<String, Object> first = seeds.load();
        assertTrue((int) first.get("dishesCreated") >= 120, first.toString());
        Map<String, Object> second = seeds.load();
        assertEquals(0, second.get("dishesCreated"), "idempotent");
        assertTrue(index.size() >= 120);
        assertTrue(index.vectors().size() >= 120, "every dish has a vector in semantic mode");
    }

    @Test @Order(2)
    @DisplayName("'Something sweet but also spicy': understood as two flavors, top results carry both")
    void sweetButSpicy() throws Exception {
        JsonNode res = search("something sweet but also spicy");
        assertEquals("HYBRID", res.get("mode").asText());
        assertEquals(List.of("sweet", "spicy"), List.of(res.get("facets").get(0).asText(), res.get("facets").get(1).asText()));
        assertEquals(Set.of("sweet", "spicy"), Set.of(res.get("flavors").get(0).asText(), res.get("flavors").get(1).asText()));
        assertEquals(10, res.get("hits").size());
        List<String> top = names(res).subList(0, 8);
        assertTrue(SWEET_AND_SPICY.containsAll(top), "top 8 should all be sweet+spicy dishes but were " + top);
        JsonNode best = res.get("hits").get(0);
        assertEquals(1.0, best.get("score").asDouble(), 1e-9);
        assertTrue(best.get("matchedTags").toString().contains("sweet") && best.get("matchedTags").toString().contains("spicy"));
        assertFalse(best.get("reasons").isEmpty());
    }

    @Test @Order(3)
    @DisplayName("Dish names and typos still work (keyword side)")
    void namesAndTypos() throws Exception {
        assertEquals("Margherita Pizza", names(search("margherita pizza")).get(0));
        assertTrue(names(search("margarita pizza")).subList(0, 3).contains("Margherita Pizza"));
        assertEquals("Butter Chicken", names(search("butter chicken")).get(0));
    }

    @Test @Order(4)
    @DisplayName("Filters from the text and from parameters: vegetarian, price, availability")
    void filters() throws Exception {
        JsonNode veg = search("spicy vegetarian");
        assertTrue(veg.get("vegOnly").asBoolean());
        veg.get("hits").forEach(h -> assertTrue(h.get("veg").asBoolean(), h.get("name").asText() + " is not vegetarian"));

        JsonNode cheap = search("dessert under 150");
        assertEquals(150.0, cheap.get("maxPrice").asDouble());
        cheap.get("hits").forEach(h -> assertTrue(h.get("price").asDouble() <= 150, h.get("name").asText()));

        MvcResult viaParam = mvc.perform(get("/search/dishes").param("q", "creamy comfort").param("veg", "true")).andExpect(status().isOk()).andReturn();
        json.readTree(viaParam.getResponse().getContentAsString()).get("hits").forEach(h -> assertTrue(h.get("veg").asBoolean()));
    }

    private List<Integer> ids(JsonNode res) {
        List<Integer> out = new ArrayList<>();
        res.get("hits").forEach(h -> out.add(h.get("itemId").asInt()));
        return out;
    }

    @Test @Order(5)
    @DisplayName("A dish that is switched off disappears from search at once and returns when switched on")
    void availabilityIsLive() throws Exception {
        // the Bella Napoli one (the starter data also has a Margherita Pizza in another restaurant)
        var margherita = items.findAll().stream()
                .filter(i -> i.getName().equals("Margherita Pizza") && i.getCategory().getRestaurant().getName().equals("Bella Napoli"))
                .findFirst().orElseThrow();
        assertTrue(ids(search("margherita pizza")).contains(margherita.getId()));

        mvc.perform(put("/menu-items/" + margherita.getId() + "/toggle").header("Authorization", ownerToken())).andExpect(status().isOk());
        assertFalse(ids(search("margherita pizza")).contains(margherita.getId()), "unavailable dishes must not be offered");

        mvc.perform(put("/menu-items/" + margherita.getId() + "/toggle").header("Authorization", ownerToken())).andExpect(status().isOk());
        assertTrue(ids(search("margherita pizza")).contains(margherita.getId()), "back on the menu");
    }

    @Test @Order(6)
    @DisplayName("Owner adds a dish with flavor tags: searchable immediately, tags stored as OWNER")
    void ownerAddsDishWithTags() throws Exception {
        MenuCategory cat = categories.findAll().stream().filter(c -> c.getRestaurant() != null).findFirst().orElseThrow();
        String body = json.writeValueAsString(Map.of("name", "Zorblax Pepper Cake", "description", "A dense cake brushed with a glaze",
                "price", 199, "isVeg", true, "isAvailable", true, "category", Map.of("id", cat.getId()),
                "ingredients", "flour, glaze", "spiceLevel", 2, "servingTemp", "room", "flavorTags", List.of("Sweet", "spicy")));
        MvcResult saved = mvc.perform(post("/menu-items").header("Authorization", ownerToken()).contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isOk()).andReturn();
        int id = json.readTree(saved.getResponse().getContentAsString()).get("id").asInt();

        assertEquals("Zorblax Pepper Cake", names(search("zorblax")).get(0));
        JsonNode hit = search("zorblax").get("hits").get(0);
        assertEquals(cat.getRestaurant().getName(), hit.get("restaurantName").asText(), "the stub category in the request must be resolved to its restaurant");
        assertEquals(cat.getRestaurant().getId(), hit.get("restaurantId").asInt());
        assertTrue(names(search("sweet but also spicy")).contains("Zorblax Pepper Cake"));

        JsonNode tags = json.readTree(mvc.perform(get("/menu-items/" + id + "/tags")).andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        assertEquals(2, tags.size());
        tags.forEach(t -> assertEquals("OWNER", t.get("source").asText()));
    }

    @Test @Order(7)
    @DisplayName("Owner input is validated: at least 2 tags, known tags only, spice and temperature ranges")
    void ownerInputValidation() throws Exception {
        MenuCategory cat = categories.findAll().stream().filter(c -> c.getRestaurant() != null).findFirst().orElseThrow();
        List<Map<String, Object>> bad = List.of(
                Map.of("flavorTags", List.of("sweet")),
                Map.of("flavorTags", List.of("sweet", "umamiiii")),
                Map.of("spiceLevel", 9, "flavorTags", List.of("sweet", "spicy")),
                Map.of("servingTemp", "LUKEWARM", "flavorTags", List.of("sweet", "spicy")));
        for (Map<String, Object> extra : bad) {
            Map<String, Object> m = new java.util.HashMap<>(Map.of("name", "Invalid Dish", "price", 100, "isVeg", true, "category", Map.of("id", cat.getId())));
            m.putAll(extra);
            mvc.perform(post("/menu-items").header("Authorization", ownerToken()).contentType(MediaType.APPLICATION_JSON)
                    .content(json.writeValueAsString(m))).andExpect(status().isBadRequest());
        }
        assertTrue(items.findAll().stream().noneMatch(i -> "Invalid Dish".equals(i.getName())), "nothing is saved when validation fails");
    }

    @Test @Order(8)
    @DisplayName("Without tags the backend suggests them (AUTO) so the dish is still findable")
    void dishWithoutTagsGetsAutoTags() throws Exception {
        MenuCategory cat = categories.findAll().stream().filter(c -> c.getRestaurant() != null).findFirst().orElseThrow();
        String body = json.writeValueAsString(Map.of("name", "Quibble Poppers", "description", "Fiery jalapeno poppers with a honey drizzle",
                "price", 150, "isVeg", true, "isAvailable", true, "category", Map.of("id", cat.getId()), "ingredients", "jalapeno, cream cheese, honey"));
        int id = json.readTree(mvc.perform(post("/menu-items").header("Authorization", ownerToken()).contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).get("id").asInt();
        JsonNode tags = json.readTree(mvc.perform(get("/menu-items/" + id + "/tags")).andReturn().getResponse().getContentAsString());
        Set<String> found = new java.util.HashSet<>();
        tags.forEach(t -> { assertEquals("AUTO", t.get("source").asText()); found.add(t.get("tag").asText()); });
        assertTrue(found.containsAll(Set.of("spicy", "sweet")), found.toString());
        assertTrue(names(search("quibble")).get(0).equals("Quibble Poppers"));
    }

    @Test @Order(9)
    @DisplayName("Live tag suggestions for the owner form; vocabulary is public, suggestions are owner-only")
    void suggestionEndpoint() throws Exception {
        String req = json.writeValueAsString(Map.of("name", "Smoky Chipotle Wings", "description", "Crispy wings in a smoky chipotle glaze"));
        mvc.perform(post("/menu-items/suggest-tags").contentType(MediaType.APPLICATION_JSON).content(req)).andExpect(status().is4xxClientError());
        JsonNode res = json.readTree(mvc.perform(post("/menu-items/suggest-tags").header("Authorization", ownerToken())
                .contentType(MediaType.APPLICATION_JSON).content(req)).andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        Set<String> tags = new java.util.HashSet<>();
        res.get("suggestions").forEach(s -> tags.add(s.get("tag").asText()));
        assertTrue(tags.containsAll(Set.of("smoky", "crunchy")), tags.toString());
        assertFalse(res.get("suggestions").get(0).get("reasons").isEmpty());

        JsonNode vocab = json.readTree(mvc.perform(get("/menu-items/flavor-tags")).andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        assertEquals(Flavor.values().length, vocab.size());
    }

    @Test @Order(10)
    @DisplayName("Input limits, public access and admin-only operations")
    void limitsAndSecurity() throws Exception {
        mvc.perform(get("/search/dishes").param("q", "a")).andExpect(status().isBadRequest());
        mvc.perform(get("/search/dishes").param("q", "x".repeat(201))).andExpect(status().isBadRequest());
        mvc.perform(get("/search/dishes")).andExpect(status().isBadRequest());

        mvc.perform(get("/admin/search/status")).andExpect(status().is4xxClientError());
        mvc.perform(get("/admin/search/status").header("Authorization", ownerToken())).andExpect(status().isForbidden());
        JsonNode st = json.readTree(mvc.perform(get("/admin/search/status").header("Authorization", adminToken()))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        assertEquals("SEMANTIC", st.get("mode").asText());

        JsonNode re = json.readTree(mvc.perform(post("/admin/search/reindex").header("Authorization", adminToken()))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        assertTrue(re.get("dishes").asInt() >= 120);
        assertEquals("Margherita Pizza", names(search("margherita pizza")).get(0), "search works after a rebuild");
    }
}
