package com.example.zomato.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/** A limited-quantity batch drop. Status is derived (see DropResponseDTO), never stored. */
@Entity
@org.hibernate.annotations.DynamicUpdate // never rewrite reservedSlots from a stale copy; it is owned by atomic UPDATEs
@Table(name = "drops")
public class Drop {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id;

    private String title;
    @Column(length = 1000)
    private String description;
    private String imageUrl;
    private double price;

    /** Links to existing catalogue rows (plain ids to avoid coupling to those entities). */
    @jakarta.validation.constraints.NotNull(message = "restaurantId is required")
    @Column(name = "restaurant_id", nullable = false)
    private Integer restaurantId;
    private Integer menuItemId;

    private LocalDateTime startsAt;
    private LocalDateTime endsAt;

    private int totalSlots;
    private int reservedSlots;

    public int getId() { return id; }
    public void setId(int id) { this.id = id; }
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public String getImageUrl() { return imageUrl; }
    public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }
    public double getPrice() { return price; }
    public void setPrice(double price) { this.price = price; }
    public Integer getRestaurantId() { return restaurantId; }
    public void setRestaurantId(Integer restaurantId) { this.restaurantId = restaurantId; }
    public Integer getMenuItemId() { return menuItemId; }
    public void setMenuItemId(Integer menuItemId) { this.menuItemId = menuItemId; }
    public LocalDateTime getStartsAt() { return startsAt; }
    public void setStartsAt(LocalDateTime startsAt) { this.startsAt = startsAt; }
    public LocalDateTime getEndsAt() { return endsAt; }
    public void setEndsAt(LocalDateTime endsAt) { this.endsAt = endsAt; }
    public int getTotalSlots() { return totalSlots; }
    public void setTotalSlots(int totalSlots) { this.totalSlots = totalSlots; }
    public int getReservedSlots() { return reservedSlots; }
    public void setReservedSlots(int reservedSlots) { this.reservedSlots = reservedSlots; }

    /**
     * Invariant: reservedSlots == count(HELD) + count(CONFIRMED).
     * Available slots is the remaining capacity.
     */
    public int getAvailableSlots() {
        return Math.max(0, totalSlots - reservedSlots);
    }
}
