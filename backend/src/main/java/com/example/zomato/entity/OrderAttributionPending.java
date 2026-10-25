package com.example.zomato.entity;

import jakarta.persistence.*;

import java.time.LocalDateTime;

/**
 * Holds "this order came from searches like X" from checkout until the order is delivered, then it is turned into a daily count and deleted
 * (or deleted unused if the order is cancelled or refunded, or after three days). It is the only place an order and a search phrase meet, and it is short lived on purpose.
 */
@Entity
@Table(name = "order_attribution_pending", indexes = @Index(name = "idx_attr_pending_order", columnList = "order_id"))
public class OrderAttributionPending {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "order_id", nullable = false)
    private int orderId;

    @Column(name = "restaurant_id", nullable = false)
    private int restaurantId;

    @Column(name = "item_id", nullable = false)
    private int itemId;

    @Column(name = "phrase_key", nullable = false, length = 200)
    private String phraseKey;

    @Column(name = "quantity", nullable = false)
    private int quantity;

    @Column(name = "amount", nullable = false)
    private double amount;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    public OrderAttributionPending() {}

    public OrderAttributionPending(int orderId, int restaurantId, int itemId, String phraseKey, int quantity, double amount) {
        this.orderId = orderId;
        this.restaurantId = restaurantId;
        this.itemId = itemId;
        this.phraseKey = phraseKey;
        this.quantity = quantity;
        this.amount = amount;
    }

    public Long getId() { return id; }
    public int getOrderId() { return orderId; }
    public int getRestaurantId() { return restaurantId; }
    public int getItemId() { return itemId; }
    public String getPhraseKey() { return phraseKey; }
    public int getQuantity() { return quantity; }
    public double getAmount() { return amount; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime v) { this.createdAt = v; }
}
