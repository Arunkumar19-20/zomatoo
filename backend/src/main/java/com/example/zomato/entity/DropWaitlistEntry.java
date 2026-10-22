package com.example.zomato.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * A customer queued for a sold-out drop. When a slot frees up it is handed straight to the
 * oldest WAITING entry as a HELD {@link DropReservation} (see DropService.freeOrHandOff).
 */
@Entity
@Table(name = "drop_waitlist")
public class DropWaitlistEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    @JoinColumn(name = "drop_id")
    private Drop drop;

    @Column(name = "customer_email", nullable = false)
    private String customerEmail;

    @Enumerated(EnumType.STRING)
    @Column(length = 20, nullable = false)
    private WaitlistStatus status = WaitlistStatus.WAITING;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    @Column(name = "offered_at")
    private LocalDateTime offeredAt;

    /** The HELD reservation created when this entry was offered a slot. */
    @Column(name = "reservation_id")
    private Integer reservationId;

    public int getId() { return id; }
    public void setId(int id) { this.id = id; }
    public Drop getDrop() { return drop; }
    public void setDrop(Drop drop) { this.drop = drop; }
    public String getCustomerEmail() { return customerEmail; }
    public void setCustomerEmail(String customerEmail) { this.customerEmail = customerEmail; }
    public WaitlistStatus getStatus() { return status; }
    public void setStatus(WaitlistStatus status) { this.status = status; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    public LocalDateTime getOfferedAt() { return offeredAt; }
    public void setOfferedAt(LocalDateTime offeredAt) { this.offeredAt = offeredAt; }
    public Integer getReservationId() { return reservationId; }
    public void setReservationId(Integer reservationId) { this.reservationId = reservationId; }
}
