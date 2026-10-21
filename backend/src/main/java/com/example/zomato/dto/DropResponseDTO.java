package com.example.zomato.dto;

import com.example.zomato.entity.Drop;
import java.time.LocalDateTime;

public record DropResponseDTO(
        int id, String title, String description, String imageUrl, double price,
        Integer restaurantId, String restaurantName, Integer menuItemId,
        LocalDateTime startsAt, LocalDateTime endsAt,
        int totalSlots, int remainingSlots,
        String status,            // SCHEDULED | LIVE | SOLD_OUT | ENDED
        LocalDateTime serverTime  // client countdowns should use this, not the device clock
) {
    public DropResponseDTO(int id, String title, String description, String imageUrl, double price,
                           Integer restaurantId, Integer menuItemId,
                           LocalDateTime startsAt, LocalDateTime endsAt,
                           int totalSlots, int remainingSlots,
                           String status, LocalDateTime serverTime) {
        this(id, title, description, imageUrl, price, restaurantId, null, menuItemId,
                startsAt, endsAt, totalSlots, remainingSlots, status, serverTime);
    }

    public static DropResponseDTO from(Drop d, LocalDateTime now, String restaurantName) {
        int remaining = Math.max(0, d.getTotalSlots() - d.getReservedSlots());
        String status;
        if (!now.isBefore(d.getEndsAt())) status = "ENDED";
        else if (now.isBefore(d.getStartsAt())) status = "SCHEDULED";
        else if (remaining == 0) status = "SOLD_OUT";
        else status = "LIVE";
        return new DropResponseDTO(d.getId(), d.getTitle(), d.getDescription(), d.getImageUrl(),
                d.getPrice(), d.getRestaurantId(), restaurantName, d.getMenuItemId(), d.getStartsAt(), d.getEndsAt(),
                d.getTotalSlots(), remaining, status, now);
    }

    public static DropResponseDTO from(Drop d, LocalDateTime now) {
        return from(d, now, null);
    }
}
