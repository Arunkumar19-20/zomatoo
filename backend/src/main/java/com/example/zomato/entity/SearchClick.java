package com.example.zomato.entity;

import jakarta.persistence.*;

import java.time.LocalDateTime;

/** A customer opened (or added to the cart) a dish from a search result. Links the search to what it led to. */
@Entity
@Table(name = "search_click", indexes = @Index(name = "idx_search_click_event", columnList = "search_event_id"))
public class SearchClick {

    public static final String OPEN = "OPEN";
    public static final String ADD_TO_CART = "ADD_TO_CART";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "search_event_id", nullable = false)
    private Long searchEventId;

    @Column(name = "item_id", nullable = false)
    private Integer itemId;

    /** 1-based position in the results */
    @Column(name = "result_rank")
    private int rank;

    @Column(name = "action", nullable = false, length = 12)
    private String action;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    public SearchClick() {}

    public SearchClick(Long searchEventId, Integer itemId, int rank, String action) {
        this.searchEventId = searchEventId;
        this.itemId = itemId;
        this.rank = rank;
        this.action = action;
    }

    public Long getId() { return id; }
    public Long getSearchEventId() { return searchEventId; }
    public Integer getItemId() { return itemId; }
    public int getRank() { return rank; }
    public String getAction() { return action; }
    public LocalDateTime getCreatedAt() { return createdAt; }
}
