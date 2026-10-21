package com.example.zomato.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.time.LocalDateTime;

public record CreateDropRequestDTO(
        @NotBlank(message = "Title is required")
        String title,
        String description,
        String imageUrl,
        @Positive(message = "Price must be positive")
        double price,
        @NotNull(message = "Restaurant ID is required")
        Integer restaurantId,
        Integer menuItemId,
        LocalDateTime startsAt,
        LocalDateTime endsAt,
        @Positive(message = "Total slots must be positive")
        int totalSlots
) {}
