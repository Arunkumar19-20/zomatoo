package com.example.zomato.search;

import java.util.List;

/** What GET /search/dishes returns: the ranked top-k plus how the craving was understood. */
public record DishSearchResponse(String query, String mode, List<String> facets, List<String> flavors, boolean vegOnly,
                                 Float maxPrice, int total, long tookMs, List<DishHit> hits, String searchId) {

    public record DishHit(int itemId, String name, String description, float price, boolean veg, String imageUrl,
                          int restaurantId, String restaurantName, boolean restaurantOpen, Integer spiceLevel,
                          String servingTemp, List<String> tags, List<String> matchedTags, double score, List<String> reasons) {}
}
