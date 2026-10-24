package com.example.zomato.search;

import com.example.zomato.entity.Location;
import com.example.zomato.entity.MenuCategory;
import com.example.zomato.entity.MenuItem;
import com.example.zomato.entity.Restaurant;
import com.example.zomato.entity.RestaurantOwner;
import com.example.zomato.repository.LocationRepository;
import com.example.zomato.repository.MenuCategoryRepository;
import com.example.zomato.repository.MenuItemRepository;
import com.example.zomato.repository.RestaurantOwnerRepository;
import com.example.zomato.repository.RestaurantRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Loads the demo catalog: 8 restaurants and about 125 dishes across Italian, BBQ, Indian, Japanese, Mexican, dessert,
 * healthy and Thai menus. The text is written for this project (synthetic, no third-party license). Each dish carries the
 * flavor tags a restaurant owner would pick; the evaluation can load it without them to measure the auto-tagger.
 */
@Service
public class SeedDishLoader {

    private final RestaurantRepository restaurants;
    private final MenuCategoryRepository categories;
    private final MenuItemRepository items;
    private final RestaurantOwnerRepository owners;
    private final LocationRepository locations;
    private final SearchIndexService index;
    private final ObjectMapper mapper = new ObjectMapper();

    public SeedDishLoader(RestaurantRepository restaurants, MenuCategoryRepository categories, MenuItemRepository items,
                          RestaurantOwnerRepository owners, LocationRepository locations, SearchIndexService index) {
        this.restaurants = restaurants;
        this.categories = categories;
        this.items = items;
        this.owners = owners;
        this.locations = locations;
        this.index = index;
    }

    /** Idempotent; dishes get their owner tags. */
    @Transactional
    public Map<String, Object> load() {
        return load(true);
    }

    @Transactional
    public Map<String, Object> load(boolean withOwnerTags) {
        JsonNode root = read();
        RestaurantOwner owner = owners.findAll().stream().findFirst()
                .orElseGet(() -> owners.save(new RestaurantOwner("Demo Owner", "demo.owner@cravey.com", "+1-555-0100")));

        Map<String, Restaurant> byName = new HashMap<>();
        for (Restaurant r : restaurants.findAll()) byName.put(r.getName(), r);
        int newRestaurants = 0;
        for (JsonNode r : root.get("restaurants")) {
            if (byName.containsKey(r.get("name").asText())) continue;
            Location loc = locations.save(new Location(37.77f, -122.41f, r.get("address").asText(), "San Francisco", "CA", "94103"));
            Restaurant rest = new Restaurant(r.get("name").asText(), r.get("address").asText(), loc, owner,
                    (float) r.get("rating").asDouble(), true, "10:00 AM - 11:00 PM", r.get("deliveryTime").asInt());
            rest.setCuisine(r.get("cuisine").asText());
            rest.setDiscount(r.get("discount").asText());
            byName.put(rest.getName(), restaurants.save(rest));
            newRestaurants++;
        }

        Map<String, MenuCategory> cats = new HashMap<>();
        for (MenuCategory c : categories.findAll()) {
            if (c.getRestaurant() != null) cats.put(c.getRestaurant().getId() + "|" + c.getName(), c);
        }
        Map<String, Boolean> existing = new HashMap<>();
        for (MenuItem i : items.findAll()) {
            if (i.getCategory() != null && i.getCategory().getRestaurant() != null) {
                existing.put(i.getCategory().getRestaurant().getId() + "|" + i.getName(), true);
            }
        }

        int created = 0;
        int order = 1;
        for (JsonNode d : root.get("dishes")) {
            Restaurant rest = byName.get(d.get("restaurant").asText());
            String catKey = rest.getId() + "|" + d.get("category").asText();
            MenuCategory cat = cats.get(catKey);
            if (cat == null) {
                cat = categories.save(new MenuCategory(d.get("category").asText(), order++, rest));
                cats.put(catKey, cat);
            }
            if (existing.containsKey(rest.getId() + "|" + d.get("name").asText())) continue;

            MenuItem item = new MenuItem(d.get("name").asText(), d.get("description").asText(), (float) d.get("price").asDouble(),
                    d.get("veg").asBoolean(), true, null, cat);
            item.setIngredients(d.get("ingredients").asText());
            item.setSpiceLevel(d.get("spiceLevel").asInt());
            item.setServingTemp(d.get("servingTemp").asText());
            item.setMood(d.get("mood").asText());
            MenuItem saved = items.save(item);
            List<String> ownerTags = null;
            if (withOwnerTags) {
                List<String> collected = new ArrayList<>();
                d.get("tags").forEach(t -> collected.add(t.asText()));
                ownerTags = collected;
            }
            index.onSaved(saved, ownerTags);
            created++;
        }
        return Map.of("restaurantsCreated", newRestaurants, "dishesCreated", created, "dishesIndexed", index.size());
    }

    /** dish name -> the tags an owner would pick (ground truth for the evaluation). */
    public Map<String, List<String>> groundTruth() {
        Map<String, List<String>> out = new HashMap<>();
        for (JsonNode d : read().get("dishes")) {
            List<String> tags = new ArrayList<>();
            d.get("tags").forEach(t -> tags.add(t.asText()));
            out.put(d.get("name").asText(), tags);
        }
        return out;
    }

    private JsonNode read() {
        try (InputStream in = new ClassPathResource("search/seed-dishes.json").getInputStream()) {
            return mapper.readTree(in);
        } catch (IOException e) {
            throw new IllegalStateException("seed-dishes.json missing: " + e.getMessage(), e);
        }
    }
}
