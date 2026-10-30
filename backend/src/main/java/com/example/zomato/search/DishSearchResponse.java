package com.example.zomato.search;

import java.util.List;

/** What GET /search/dishes returns: the ranked top-k plus how the craving was understood. */
public record DishSearchResponse(String query, String mode, List<String> facets, List<String> flavors, boolean vegOnly,
                                 Float maxPrice, int total, long tookMs, List<DishHit> hits, String searchId) {

    public record DishHit(int itemId, String name, String description, float price, boolean veg, String imageUrl,
                          int restaurantId, String restaurantName, boolean restaurantOpen, Integer spiceLevel,
                          String servingTemp, List<String> tags, List<String> matchedTags, double score, List<String> reasons,
                          /** the restaurant's cuisine as the owner wrote it, e.g. "Italian, American, Comfort Food" (null if not set) */
                          String cuisine,
                          /** a Drop for this dish that is live right now and has a slot left, or null */
                          LiveDrop liveDrop) {

        /** Keeps the shape from before Drops were shown in results, for code that does not know about them. */
        public DishHit(int itemId, String name, String description, float price, boolean veg, String imageUrl, int restaurantId, String restaurantName,
                       boolean restaurantOpen, Integer spiceLevel, String servingTemp, List<String> tags, List<String> matchedTags, double score,
                       List<String> reasons, String cuisine) {
            this(itemId, name, description, price, veg, imageUrl, restaurantId, restaurantName, restaurantOpen, spiceLevel, servingTemp, tags, matchedTags,
                    score, reasons, cuisine, null);
        }
    }

    /** What a result card needs to show "Drop live: 3 left" and open the Drop. */
    public record LiveDrop(int dropId, String title, double price, int slotsLeft, java.time.LocalDateTime endsAt) {}
}
