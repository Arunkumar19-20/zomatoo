package com.example.zomato.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "drop_reservations")
public class DropReservation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    @JoinColumn(name = "drop_id")
    private Drop drop;

    private String customerEmail;

    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    private ReservationStatus status = ReservationStatus.HELD;

    private LocalDateTime createdAt;
    private LocalDateTime expiresAt;
    private Integer orderId;

    /** The search phrase (never the query or the search id) that led to this reservation, kept at most 24 hours; see OrderAttributionService. */
    @Column(name = "search_attribution", length = 200)
    private String searchAttribution;

    @Column(name = "search_attribution_at")
    private LocalDateTime searchAttributionAt;

    public int getId() { return id; }
    public void setId(int id) { this.id = id; }
    public Drop getDrop() { return drop; }
    public void setDrop(Drop drop) { this.drop = drop; }
    public String getCustomerEmail() { return customerEmail; }
    public void setCustomerEmail(String customerEmail) { this.customerEmail = customerEmail; }
    public ReservationStatus getStatus() { return status; }
    public void setStatus(ReservationStatus status) { this.status = status; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    public LocalDateTime getExpiresAt() { return expiresAt; }
    public void setExpiresAt(LocalDateTime expiresAt) { this.expiresAt = expiresAt; }
    public String getSearchAttribution() { return searchAttribution; }
    public void setSearchAttribution(String searchAttribution) { this.searchAttribution = searchAttribution; }
    public LocalDateTime getSearchAttributionAt() { return searchAttributionAt; }
    public void setSearchAttributionAt(LocalDateTime searchAttributionAt) { this.searchAttributionAt = searchAttributionAt; }
    public Integer getOrderId() { return orderId; }
    public void setOrderId(Integer orderId) { this.orderId = orderId; }
}
