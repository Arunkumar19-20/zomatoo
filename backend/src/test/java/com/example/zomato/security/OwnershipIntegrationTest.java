package com.example.zomato.security;

import com.example.zomato.entity.MenuCategory;
import com.example.zomato.entity.MenuItem;
import com.example.zomato.entity.Restaurant;
import com.example.zomato.entity.RestaurantOwner;
import com.example.zomato.repository.DropRepository;
import com.example.zomato.repository.MenuCategoryRepository;
import com.example.zomato.repository.MenuItemRepository;
import com.example.zomato.repository.RestaurantOwnerRepository;
import com.example.zomato.repository.RestaurantRepository;
import com.example.zomato.search.NoEmbeddingProvider;
import com.example.zomato.search.EmbeddingProvider;
import com.example.zomato.search.SeedDishLoader;
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

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Having the OWNER role must not let you change someone else's restaurant, menu or Drops. Owner A owns Casa Fuego, owner B owns Bella Napoli,
 * a third owner has no restaurant at all; every endpoint that changes a restaurant, a menu section, a dish or a Drop is tried against the others'.
 */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:ownership;DB_CLOSE_DELAY=-1;MODE=PostgreSQL")
@AutoConfigureMockMvc
@Import(OwnershipIntegrationTest.Cfg.class)
class OwnershipIntegrationTest {

    @TestConfiguration
    static class Cfg {
        @Bean
        @Primary
        EmbeddingProvider none() { return new NoEmbeddingProvider(); }
    }

    private static final String A = "owner.a@cravey.test";
    private static final String B = "owner.b@cravey.test";
    private static final String NOBODY = "owner.none@cravey.test";

    @Autowired MockMvc mvc;
    @Autowired SeedDishLoader seeds;
    @Autowired RestaurantRepository restaurants;
    @Autowired RestaurantOwnerRepository owners;
    @Autowired MenuCategoryRepository categories;
    @Autowired MenuItemRepository items;
    @Autowired DropRepository drops;
    @Autowired JwtService jwt;
    private final ObjectMapper json = new ObjectMapper();

    private int casa, bella;          // restaurant ids
    private RestaurantOwner ownerA, ownerB;

    @BeforeEach
    void setUp() {
        seeds.load();
        for (Restaurant r : restaurants.findAll()) if (r.getOwner() != null) { r.setOwner(null); restaurants.save(r); }
        ownerA = owners.findByEmailIgnoreCase(A).stream().findFirst().orElseGet(() -> owners.save(new RestaurantOwner("Owner A", A, "1")));
        ownerB = owners.findByEmailIgnoreCase(B).stream().findFirst().orElseGet(() -> owners.save(new RestaurantOwner("Owner B", B, "2")));
        casa = own("Casa Fuego", ownerA);
        bella = own("Bella Napoli", ownerB);
    }

    private int own(String name, RestaurantOwner o) {
        Restaurant r = restaurants.findAll().stream().filter(x -> x.getName().equals(name)).findFirst().orElseThrow();
        r.setOwner(o);
        return restaurants.save(r).getId();
    }

    private String token(String email, String role) { return "Bearer " + jwt.generateToken(email, role); }

    private int categoryOf(int restaurantId) {
        return categories.findAll().stream().filter(c -> c.getRestaurant() != null && c.getRestaurant().getId() == restaurantId).findFirst().orElseThrow().getId();
    }

    private int itemOf(int restaurantId) {
        for (MenuItem i : items.findAll()) {
            MenuCategory c = i.getCategory();
            if (c != null && c.getRestaurant() != null && c.getRestaurant().getId() == restaurantId) return i.getId();
        }
        throw new AssertionError("no dish at " + restaurantId);
    }

    private int code(MockHttpServletRequestBuilder req, String who) throws Exception {
        return mvc.perform(req.header("Authorization", token(who, who.equals("admin@cravey.test") ? "ADMIN" : "OWNER"))).andReturn().getResponse().getStatus();
    }

    private static final String ADMIN = "admin@cravey.test";

    private MockHttpServletRequestBuilder jsonReq(MockHttpServletRequestBuilder b, String body) { return b.contentType(MediaType.APPLICATION_JSON).content(body); }

    private String newDish(int categoryId) { return "{\"name\":\"Test Dish\",\"price\":120,\"available\":true,\"category\":{\"id\":" + categoryId + "}}"; }

    private int newDrop(int restaurantId) throws Exception {
        String start = LocalDateTime.now().plusHours(1).withNano(0).toString(), end = LocalDateTime.now().plusHours(3).withNano(0).toString();
        String body = "{\"title\":\"Drop\",\"price\":99,\"restaurantId\":" + restaurantId + ",\"startsAt\":\"" + start + "\",\"endsAt\":\"" + end + "\",\"totalSlots\":5}";
        JsonNode d = json.readTree(mvc.perform(jsonReq(post("/drops"), body).header("Authorization", token(ADMIN, "ADMIN"))).andExpect(status().isCreated()).andReturn().getResponse().getContentAsString());
        return d.get("id").asInt();
    }

    // ------------------------------------------------------------------ restaurants

    @Test
    void anOwnerCanChangeTheirOwnRestaurantAndNotAnothers() throws Exception {
        assertEquals(200, code(put("/restaurants/" + casa + "/status").param("isOpen", "false"), A));
        assertEquals(403, code(put("/restaurants/" + bella + "/status").param("isOpen", "false"), A));
        assertEquals(403, code(put("/owners/manage/" + bella), A));
        assertEquals(200, code(put("/owners/manage/" + casa), A));

        String update = "{\"name\":\"Renamed\",\"address\":\"x\",\"rating\":4.0,\"open\":true,\"cuisine\":\"Mexican\"}";
        assertEquals(403, code(jsonReq(put("/restaurants/" + bella), update), A));
        assertEquals("Bella Napoli", restaurants.findById(bella).orElseThrow().getName(), "nothing changed");
        assertEquals(200, code(jsonReq(put("/restaurants/" + casa), update.replace("Renamed", "Casa Fuego")), A));

        assertEquals(403, code(delete("/restaurants/" + bella), A));
        assertTrue(restaurants.existsById(bella), "still there");
    }

    @Test
    void anOwnerCreatesRestaurantsOnlyUnderTheirOwnRecord() throws Exception {
        // the request names owner B; the server ignores that and uses the caller's own record
        String body = "{\"name\":\"A's Second Place\",\"address\":\"y\",\"cuisine\":\"Thai\",\"owner\":{\"ownerId\":" + ownerB.getOwnerId() + "}}";
        JsonNode created = json.readTree(mvc.perform(jsonReq(post("/restaurants"), body).header("Authorization", token(A, "OWNER"))).andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        Restaurant r = restaurants.findById(created.get("id").asInt()).orElseThrow();
        assertEquals(ownerA.getOwnerId(), r.getOwner().getOwnerId(), "owned by the caller, not by whoever the request named");

        assertEquals(403, code(jsonReq(post("/restaurants"), body), NOBODY), "no owner profile, no restaurant");
        JsonNode byAdmin = json.readTree(mvc.perform(jsonReq(post("/restaurants"), body).header("Authorization", token(ADMIN, "ADMIN"))).andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        assertEquals(ownerB.getOwnerId(), restaurants.findById(byAdmin.get("id").asInt()).orElseThrow().getOwner().getOwnerId(), "an admin may assign any owner");
    }

    // ------------------------------------------------------------------ dishes

    @Test
    void dishesCanBeChangedOnlyByTheirRestaurantsOwner() throws Exception {
        int mine = itemOf(casa), theirs = itemOf(bella);
        assertEquals(200, code(put("/menu-items/" + mine + "/toggle"), A));
        assertEquals(200, code(put("/menu-items/" + mine + "/price").param("price", "250"), A));

        Boolean before = items.findById(theirs).orElseThrow().getIsAvailable();
        assertEquals(403, code(put("/menu-items/" + theirs + "/toggle"), A));
        assertEquals(403, code(put("/menu-items/" + theirs + "/price").param("price", "1"), A));
        assertEquals(403, code(delete("/menu-items/" + theirs), A));
        assertEquals(before, items.findById(theirs).orElseThrow().getIsAvailable(), "untouched");
        assertNotEquals(1.0f, items.findById(theirs).orElseThrow().getPrice());
        assertTrue(items.existsById(theirs));
        assertEquals(403, code(put("/menu-items/" + theirs + "/toggle"), NOBODY), "an owner with no restaurant owns no dish");
    }

    @Test
    void aNewDishGoesIntoTheCallersOwnMenuSectionOnly() throws Exception {
        assertEquals(200, code(jsonReq(post("/menu-items"), newDish(categoryOf(casa))), A));
        long before = items.count();
        assertEquals(403, code(jsonReq(post("/menu-items"), newDish(categoryOf(bella))), A));
        assertEquals(before, items.count(), "nothing was created in someone else's menu");
        assertEquals(400, code(jsonReq(post("/menu-items"), "{\"name\":\"No section\",\"price\":5}"), A), "an owner's dish needs a section of their own");
        assertEquals(200, code(jsonReq(post("/menu-items"), newDish(categoryOf(bella))), ADMIN));
    }

    @Test
    void aDishCannotBeMovedIntoSomeoneElsesMenu() throws Exception {
        int mine = itemOf(casa);
        assertEquals(403, code(jsonReq(put("/menu-items/" + mine), newDish(categoryOf(bella))), A));
        assertEquals(casa, items.findById(mine).orElseThrow().getCategory().getRestaurant().getId(), "still at the original restaurant");
        assertEquals(200, code(jsonReq(put("/menu-items/" + mine), newDish(categoryOf(casa))), A));
    }

    @Test
    void aMissingDishIsNotFoundNotForbidden() throws Exception {
        assertEquals(404, code(put("/menu-items/999999/toggle"), A));
    }

    // ------------------------------------------------------------------ menu sections

    @Test
    void menuSectionsFollowTheSameRule() throws Exception {
        String section = "{\"name\":\"Specials\",\"displayOrder\":9}";
        assertEquals(200, code(jsonReq(post("/categories/" + casa), section), A));
        long before = categories.count();
        assertEquals(403, code(jsonReq(post("/categories/" + bella), section), A));
        assertEquals(before, categories.count());

        int theirs = categoryOf(bella), mine = categoryOf(casa);
        assertEquals(403, code(jsonReq(put("/categories/" + theirs), section), A));
        assertEquals(403, code(delete("/categories/" + theirs), A));
        assertTrue(categories.existsById(theirs));
        assertEquals(200, code(jsonReq(put("/categories/" + mine), section), A));

        assertEquals(403, code(jsonReq(post("/categories/add-item"), newDish(theirs)), A));
        assertEquals(403, code(delete("/categories/remove-item/" + itemOf(bella)), A));
        assertEquals(403, code(jsonReq(post("/restaurants/menu-item"), newDish(theirs)), A));
        assertEquals(403, code(delete("/restaurants/menu-item/" + itemOf(bella)), A));
    }

    // ------------------------------------------------------------------ Drops

    @Test
    void dropsCanBeCreatedChangedAndDeletedOnlyByTheRestaurantsOwner() throws Exception {
        String start = LocalDateTime.now().plusHours(1).withNano(0).toString(), end = LocalDateTime.now().plusHours(3).withNano(0).toString();
        java.util.function.IntFunction<String> body = rid ->
                "{\"title\":\"Mine\",\"price\":99,\"restaurantId\":" + rid + ",\"startsAt\":\"" + start + "\",\"endsAt\":\"" + end + "\",\"totalSlots\":5}";

        assertEquals(201, code(jsonReq(post("/drops"), body.apply(casa)), A));
        long before = drops.count();
        assertEquals(403, code(jsonReq(post("/drops"), body.apply(bella)), A), "a Drop for someone else's restaurant");
        assertEquals(before, drops.count());

        int mine = newDrop(casa), theirs = newDrop(bella);
        assertEquals(200, code(jsonReq(put("/drops/" + mine), body.apply(casa).replace("Mine", "Renamed")), A));
        assertEquals(403, code(jsonReq(put("/drops/" + theirs), body.apply(bella).replace("Mine", "Hijacked")), A));
        assertNotEquals("Hijacked", drops.findById(theirs).orElseThrow().getTitle());
        assertEquals(403, code(jsonReq(put("/drops/" + mine), body.apply(bella)), A), "and it cannot be moved to someone else's restaurant");
        assertEquals(casa, drops.findById(mine).orElseThrow().getRestaurantId());

        assertEquals(403, code(delete("/drops/" + theirs), A));
        assertTrue(drops.existsById(theirs));
        assertEquals(204, code(delete("/drops/" + mine), A));
        assertEquals(403, code(jsonReq(post("/drops"), body.apply(casa)), NOBODY));
    }

    // ------------------------------------------------------------------ admins and the owner directory

    @Test
    void anAdminIsNotLimited() throws Exception {
        assertEquals(200, code(put("/restaurants/" + bella + "/status").param("isOpen", "true"), ADMIN));
        assertEquals(200, code(put("/menu-items/" + itemOf(bella) + "/toggle"), ADMIN));
        int theirs = newDrop(bella);
        assertEquals(204, code(delete("/drops/" + theirs), ADMIN));
    }

    @Test
    void ownerContactDetailsAreForAdminsAndTheOwnerThemselves() throws Exception {
        assertEquals(403, code(get("/owners"), A), "the list of every owner's email and phone");
        assertEquals(200, code(get("/owners"), ADMIN));

        assertEquals(200, code(get("/owners/" + ownerA.getOwnerId()), A));
        assertEquals(403, code(get("/owners/" + ownerB.getOwnerId()), A));
        assertEquals(200, code(get("/owners/" + ownerB.getOwnerId()), ADMIN));
        assertEquals(200, code(get("/owners/" + ownerA.getOwnerId() + "/restaurants"), A));
        assertEquals(403, code(get("/owners/" + ownerB.getOwnerId() + "/restaurants"), A));
        assertEquals(403, mvc.perform(get("/owners/" + ownerA.getOwnerId()).header("Authorization", token("customer@cravey.test", "CUSTOMER"))).andReturn().getResponse().getStatus());
        assertEquals(401, mvc.perform(get("/owners")).andReturn().getResponse().getStatus());
    }

    @Test
    void readingMenusAndRestaurantsStaysPublic() throws Exception {
        mvc.perform(get("/restaurants/" + bella + "/menu")).andExpect(status().isOk());
        mvc.perform(get("/menu-items")).andExpect(status().isOk());
        mvc.perform(get("/drops")).andExpect(status().isOk());
    }
}
