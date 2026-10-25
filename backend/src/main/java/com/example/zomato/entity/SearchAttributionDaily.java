package com.example.zomato.entity;

import jakarta.persistence.*;

import java.time.LocalDate;

/**
 * Delivered orders that search brought in, counted per day, search phrase, restaurant and dish. Holds no order id, customer or search id:
 * once an order is counted nothing can say which order it was.
 */
@Entity
@Table(name = "search_attribution_daily",
        uniqueConstraints = @UniqueConstraint(name = "uq_search_attr_day", columnNames = {"order_day", "phrase_key", "item_id", "simulated"}),
        indexes = @Index(name = "idx_search_attr_rest", columnList = "restaurant_id, order_day"))
public class SearchAttributionDaily {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "order_day", nullable = false)
    private LocalDate orderDay;

    @Column(name = "phrase_key", nullable = false, length = 200)
    private String phraseKey;

    @Column(name = "restaurant_id", nullable = false)
    private int restaurantId;

    @Column(name = "item_id", nullable = false)
    private int itemId;

    @Column(name = "orders", nullable = false)
    private int orders;

    @Column(name = "units", nullable = false)
    private int units;

    @Column(name = "revenue", nullable = false)
    private double revenue;

    @Column(name = "simulated", nullable = false)
    private boolean simulated;

    public SearchAttributionDaily() {}

    public SearchAttributionDaily(LocalDate orderDay, String phraseKey, int restaurantId, int itemId, boolean simulated) {
        this.orderDay = orderDay;
        this.phraseKey = phraseKey;
        this.restaurantId = restaurantId;
        this.itemId = itemId;
        this.simulated = simulated;
    }

    public void add(int orders, int units, double revenue) {
        this.orders += orders;
        this.units += units;
        this.revenue += revenue;
    }

    public Long getId() { return id; }
    public LocalDate getOrderDay() { return orderDay; }
    public String getPhraseKey() { return phraseKey; }
    public int getRestaurantId() { return restaurantId; }
    public int getItemId() { return itemId; }
    public int getOrders() { return orders; }
    public int getUnits() { return units; }
    public double getRevenue() { return revenue; }
    public boolean isSimulated() { return simulated; }
}
