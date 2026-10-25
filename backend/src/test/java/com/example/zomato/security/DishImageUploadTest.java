package com.example.zomato.security;

import com.example.zomato.entity.MenuCategory;
import com.example.zomato.entity.MenuItem;
import com.example.zomato.entity.Restaurant;
import com.example.zomato.entity.RestaurantOwner;
import com.example.zomato.repository.MenuItemRepository;
import com.example.zomato.repository.RestaurantOwnerRepository;
import com.example.zomato.repository.RestaurantRepository;
import com.example.zomato.search.EmbeddingProvider;
import com.example.zomato.search.NoEmbeddingProvider;
import com.example.zomato.search.SeedDishLoader;
import com.example.zomato.services.DishImageService;
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
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.stream.Stream;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Owners upload photos for their own dishes: what is accepted, who may, where it goes, and what is cleaned up. */
@SpringBootTest(properties = {"spring.datasource.url=jdbc:h2:mem:dish_images;DB_CLOSE_DELAY=-1;MODE=PostgreSQL", "uploads.dir=target/test-uploads"})
@AutoConfigureMockMvc
@Import(DishImageUploadTest.Cfg.class)
class DishImageUploadTest {

    @TestConfiguration
    static class Cfg {
        @Bean
        @Primary
        EmbeddingProvider none() { return new NoEmbeddingProvider(); }
    }

    private static final String A = "photo.a@cravey.test";
    private static final String B = "photo.b@cravey.test";
    private static final byte[] SIG_PNG = {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A};
    private static final byte[] SIG_JPG = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF};
    private static final byte[] SIG_WEBP = {'R', 'I', 'F', 'F', 1, 0, 0, 0, 'W', 'E', 'B', 'P'};
    private static final byte[] SIG_GIF = {'G', 'I', 'F', '8', '9', 'a'};
    private static final String PREFIX = "/uploads/dishes/";

    @Autowired MockMvc mvc;
    @Autowired SeedDishLoader seeds;
    @Autowired RestaurantRepository restaurants;
    @Autowired RestaurantOwnerRepository owners;
    @Autowired MenuItemRepository items;
    @Autowired DishImageService images;
    @Autowired JwtService jwt;
    private final ObjectMapper json = new ObjectMapper();

    private int casaItem, bellaItem;

    @BeforeEach
    void setUp() {
        seeds.load();
        for (Restaurant r : restaurants.findAll()) if (r.getOwner() != null) { r.setOwner(null); restaurants.save(r); }
        RestaurantOwner a = owners.findByEmailIgnoreCase(A).stream().findFirst().orElseGet(() -> owners.save(new RestaurantOwner("A", A, "1")));
        RestaurantOwner b = owners.findByEmailIgnoreCase(B).stream().findFirst().orElseGet(() -> owners.save(new RestaurantOwner("B", B, "2")));
        casaItem = itemAt("Casa Fuego", a);
        bellaItem = itemAt("Bella Napoli", b);
        for (int id : new int[]{casaItem, bellaItem}) { MenuItem i = items.findById(id).orElseThrow(); i.setImageUrl(null); items.save(i); }
    }

    private int itemAt(String restaurant, RestaurantOwner owner) {
        Restaurant r = restaurants.findAll().stream().filter(x -> x.getName().equals(restaurant)).findFirst().orElseThrow();
        r.setOwner(owner);
        restaurants.save(r);
        for (MenuItem i : items.findAll()) {
            MenuCategory c = i.getCategory();
            if (c != null && c.getRestaurant() != null && c.getRestaurant().getId() == r.getId()) return i.getId();
        }
        throw new AssertionError("no dish at " + restaurant);
    }

    private String token(String email, String role) { return "Bearer " + jwt.generateToken(email, role); }

    private static byte[] withSignature(byte[] sig, int totalSize) {
        byte[] b = new byte[Math.max(totalSize, sig.length)];
        Arrays.fill(b, (byte) 7);
        System.arraycopy(sig, 0, b, 0, sig.length);
        return b;
    }

    private MvcResult upload(int itemId, byte[] data, String filename, String contentType, String who, String role) throws Exception {
        return mvc.perform(multipart("/menu-items/" + itemId + "/image").file(new MockMultipartFile("file", filename, contentType, data))
                .header("Authorization", token(who, role))).andReturn();
    }

    private int uploadCode(int itemId, byte[] data, String filename, String contentType, String who, String role) throws Exception {
        return upload(itemId, data, filename, contentType, who, role).getResponse().getStatus();
    }

    private Path fileOf(String url) { return images.root().resolve("dishes").resolve(url.substring(PREFIX.length())); }

    private long filesStored() throws Exception {
        Path dir = images.root().resolve("dishes");
        if (!Files.isDirectory(dir)) return 0;
        try (Stream<Path> s = Files.list(dir)) { return s.count(); }
    }

    private JsonNode body(MvcResult r) throws Exception { return json.readTree(r.getResponse().getContentAsString()); }

    // ------------------------------------------------------------------ the happy path

    @Test
    void anOwnerUploadsAPhotoForTheirDishAndEveryoneCanSeeIt() throws Exception {
        byte[] png = withSignature(SIG_PNG, 500);
        MvcResult r = upload(casaItem, png, "my dish.png", "image/png", A, "OWNER");
        assertEquals(200, r.getResponse().getStatus(), r.getResponse().getContentAsString());
        String url = body(r).get("imageUrl").asText();
        assertTrue(url.startsWith(PREFIX) && url.endsWith(".png"), url);
        assertEquals(url, items.findById(casaItem).orElseThrow().getImageUrl());

        // anyone, signed in or not, can load it
        MvcResult served = mvc.perform(get(url)).andExpect(status().isOk()).andReturn();
        assertArrayEquals(png, served.getResponse().getContentAsByteArray());

        // and search results carry it
        String name = items.findById(casaItem).orElseThrow().getName();
        JsonNode hits = json.readTree(mvc.perform(get("/search/dishes").param("q", name).param("k", "10"))
                .andReturn().getResponse().getContentAsString()).get("hits");
        boolean found = false;
        for (JsonNode h : hits) if (h.get("itemId").asInt() == casaItem) { assertEquals(url, h.get("imageUrl").asText()); found = true; }
        assertTrue(found, "the dish is in its own search results");
    }

    @Test
    void jpegAndWebpAreAcceptedToo() throws Exception {
        assertTrue(body(upload(casaItem, withSignature(SIG_JPG, 300), "a.jpg", "image/jpeg", A, "OWNER")).get("imageUrl").asText().endsWith(".jpg"));
        assertTrue(body(upload(casaItem, withSignature(SIG_WEBP, 300), "a.webp", "image/webp", A, "OWNER")).get("imageUrl").asText().endsWith(".webp"));
    }

    // ------------------------------------------------------------------ what counts as a photo

    @Test
    void onlyRealImagesAreAcceptedWhateverTheyClaimToBe() throws Exception {
        long before = filesStored();
        assertEquals(400, uploadCode(casaItem, "<html>not an image</html>".getBytes(), "evil.png", "image/png", A, "OWNER"), "text claiming to be a png");
        assertEquals(400, uploadCode(casaItem, withSignature(SIG_GIF, 100), "a.gif", "image/gif", A, "OWNER"), "gif is not on the list");
        assertEquals(400, uploadCode(casaItem, new byte[0], "empty.png", "image/png", A, "OWNER"));
        assertEquals(before, filesStored(), "nothing was written");
        assertNull(items.findById(casaItem).orElseThrow().getImageUrl());
    }

    @Test
    void thereIsASizeLimit() throws Exception {
        assertEquals(200, uploadCode(casaItem, withSignature(SIG_PNG, 2 * 1024 * 1024), "big.png", "image/png", A, "OWNER"), "exactly 2 MB is fine");
        long before = filesStored();
        assertEquals(413, uploadCode(casaItem, withSignature(SIG_PNG, 2 * 1024 * 1024 + 1), "big.png", "image/png", A, "OWNER"));
        assertEquals(before, filesStored());
    }

    @Test
    void theClientNeverChoosesTheFileName() throws Exception {
        MvcResult r = upload(casaItem, withSignature(SIG_PNG, 100), "../../../etc/evil.png", "image/png", A, "OWNER");
        assertEquals(200, r.getResponse().getStatus());
        String url = body(r).get("imageUrl").asText();
        assertTrue(url.matches("/uploads/dishes/[0-9a-f-]{36}\\.png"), "a random name inside the photos folder: " + url);
        assertTrue(Files.exists(fileOf(url)));
    }

    // ------------------------------------------------------------------ who may

    @Test
    void onlyTheDishsOwnerOrAnAdminMayChangeItsPhoto() throws Exception {
        long before = filesStored();
        byte[] png = withSignature(SIG_PNG, 100);
        assertEquals(403, uploadCode(bellaItem, png, "x.png", "image/png", A, "OWNER"), "another restaurant's dish");
        assertEquals(403, uploadCode(casaItem, png, "x.png", "image/png", "customer@cravey.test", "CUSTOMER"));
        assertEquals(before, filesStored());
        assertNull(items.findById(bellaItem).orElseThrow().getImageUrl());
        assertEquals(401, mvc.perform(multipart("/menu-items/" + casaItem + "/image").file(new MockMultipartFile("file", "x.png", "image/png", png)))
                .andReturn().getResponse().getStatus());
        assertEquals(200, uploadCode(bellaItem, png, "x.png", "image/png", "admin@cravey.test", "ADMIN"));
        assertEquals(404, uploadCode(999999, png, "x.png", "image/png", "admin@cravey.test", "ADMIN"));
    }

    @Test
    void anotherOwnerCannotRemoveThePhoto() throws Exception {
        upload(casaItem, withSignature(SIG_PNG, 100), "x.png", "image/png", A, "OWNER");
        assertEquals(403, mvc.perform(delete("/menu-items/" + casaItem + "/image").header("Authorization", token(B, "OWNER"))).andReturn().getResponse().getStatus());
        assertNotNull(items.findById(casaItem).orElseThrow().getImageUrl());
    }

    // ------------------------------------------------------------------ cleanup

    @Test
    void replacingAPhotoDeletesTheOldFile() throws Exception {
        String first = body(upload(casaItem, withSignature(SIG_PNG, 100), "1.png", "image/png", A, "OWNER")).get("imageUrl").asText();
        assertTrue(Files.exists(fileOf(first)));
        String second = body(upload(casaItem, withSignature(SIG_JPG, 100), "2.jpg", "image/jpeg", A, "OWNER")).get("imageUrl").asText();
        assertNotEquals(first, second);
        assertFalse(Files.exists(fileOf(first)), "the old photo is gone");
        mvc.perform(get(first)).andExpect(status().isNotFound());
        mvc.perform(get(second)).andExpect(status().isOk());
    }

    @Test
    void removingAPhotoAndDeletingADishBothCleanUp() throws Exception {
        String url = body(upload(casaItem, withSignature(SIG_PNG, 100), "1.png", "image/png", A, "OWNER")).get("imageUrl").asText();
        MvcResult removed = mvc.perform(delete("/menu-items/" + casaItem + "/image").header("Authorization", token(A, "OWNER"))).andReturn();
        assertEquals(200, removed.getResponse().getStatus());
        assertTrue(body(removed).get("imageUrl").isNull());
        assertFalse(Files.exists(fileOf(url)));

        String url2 = body(upload(casaItem, withSignature(SIG_PNG, 100), "1.png", "image/png", A, "OWNER")).get("imageUrl").asText();
        assertTrue(Files.exists(fileOf(url2)));
        mvc.perform(delete("/menu-items/" + casaItem).header("Authorization", token(A, "OWNER"))).andExpect(status().isOk());
        assertFalse(Files.exists(fileOf(url2)), "a deleted dish takes its photo with it");
    }

    @Test
    void aPhotoLinkToAnotherSiteIsLeftAloneWhenReplaced() throws Exception {
        MenuItem i = items.findById(casaItem).orElseThrow();
        i.setImageUrl("https://images.example.com/dish.jpg");
        items.save(i);
        assertEquals(200, uploadCode(casaItem, withSignature(SIG_PNG, 100), "x.png", "image/png", A, "OWNER"));
        assertTrue(items.findById(casaItem).orElseThrow().getImageUrl().startsWith(PREFIX));
    }

    @Test
    void deletionCannotEscapeThePhotosFolder() throws Exception {
        Files.createDirectories(images.root());
        Path decoy = images.root().resolve("decoy.txt");
        Files.writeString(decoy, "keep me");
        images.deleteIfOurs("/uploads/dishes/../decoy.txt");
        images.deleteIfOurs("/uploads/dishes/..%2Fdecoy.txt");
        images.deleteIfOurs("/etc/passwd");
        images.deleteIfOurs(null);
        assertTrue(Files.exists(decoy), "only files this service named itself can be deleted");
    }

    @Test
    void theUploadsFolderServesPhotosAndNothingElse() throws Exception {
        Files.createDirectories(images.root());
        Files.writeString(images.root().resolve("secret.txt"), "private");
        mvc.perform(get("/uploads/dishes/../secret.txt")).andExpect(status().is4xxClientError());
        mvc.perform(get("/uploads/secret.txt")).andExpect(status().is4xxClientError());
        mvc.perform(get("/uploads/dishes/does-not-exist.png")).andExpect(status().isNotFound());
    }
}
