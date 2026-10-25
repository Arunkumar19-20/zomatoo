package com.example.zomato.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;

@Entity
@Table(name = "cart_item")
public class CartItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "cart_id")
    @JsonIgnore
    private Cart cart;

    @ManyToOne
    @JoinColumn(name = "item_id")
    @JsonIgnore
    private MenuItem item;

    private Double price;
    private Integer quantity;

    /**
     * The search phrase that led the customer to add this dish (a phrase key like "dish:birria+taco", never their query), kept only
     * until checkout or 24 hours, whichever comes first. Used to count orders that search brought in, in aggregate.
     */
    @JsonIgnore
    @Column(name = "search_attribution", length = 200)
    private String searchAttribution;

    @JsonIgnore
    @Column(name = "search_attribution_at")
    private java.time.LocalDateTime searchAttributionAt;

    public Integer getId() { return id; }

    public Cart getCart() { return cart; }
    public void setCart(Cart cart) { this.cart = cart; }

    public MenuItem getItem() { return item; }
    public void setItem(MenuItem item) { this.item = item; }

    public Double getPrice() { return price; }
    public void setPrice(Double price) { this.price = price; }

    public String getSearchAttribution() { return searchAttribution; }
    public void setSearchAttribution(String v) { this.searchAttribution = v; }
    public java.time.LocalDateTime getSearchAttributionAt() { return searchAttributionAt; }
    public void setSearchAttributionAt(java.time.LocalDateTime v) { this.searchAttributionAt = v; }

    public Integer getQuantity() { return quantity; }
    public void setQuantity(Integer quantity) { this.quantity = quantity; }
}
