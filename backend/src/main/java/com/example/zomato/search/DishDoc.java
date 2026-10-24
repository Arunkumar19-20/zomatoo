package com.example.zomato.search;

import java.util.Map;

/**
 * Everything search needs to know about one dish, flattened out of the JPA entities so ranking never touches the
 * database. {@code tags} maps a flavor to its weight: 1.0 for owner-confirmed, the tagger's confidence otherwise.
 */
public record DishDoc(
        int itemId,
        String name,
        String description,
        String ingredients,
        String category,
        String mood,
        Integer spiceLevel,
        String servingTemp,
        boolean veg,
        boolean available,
        float price,
        String imageUrl,
        int restaurantId,
        String restaurantName,
        String cuisine,
        boolean restaurantOpen,
        Map<Flavor, Double> tags,
        Map<Flavor, Boolean> ownerTags) {

    /** Text that gets embedded: reads like a short menu blurb so the model sees what a customer would read. */
    public String embeddingText() {
        StringBuilder sb = new StringBuilder(name).append('.');
        if (description != null && !description.isBlank()) sb.append(' ').append(description.trim());
        if (ingredients != null && !ingredients.isBlank()) sb.append(" Ingredients: ").append(ingredients.trim()).append('.');
        if (category != null && !category.isBlank()) sb.append(' ').append(category).append('.');
        if (cuisine != null && !cuisine.isBlank()) sb.append(' ').append(cuisine).append(" cuisine.");
        sb.append(veg ? " Vegetarian." : "");
        if (!tags.isEmpty()) {
            sb.append(" Flavor: ");
            sb.append(String.join(", ", tags.keySet().stream().map(Flavor::id).sorted().toList())).append('.');
        }
        if (servingTemp != null && !servingTemp.isBlank()) sb.append(" Served ").append(servingTemp.toLowerCase()).append('.');
        if (mood != null && !mood.isBlank()) sb.append(" Good for: ").append(mood).append('.');
        return sb.toString();
    }
}
