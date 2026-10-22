package com.example.zomato.entity;

import jakarta.persistence.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "payment")
public class Payment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id;

    @ManyToOne
    @JoinColumn(name = "order_id")
    private Order order;

    @Column(name = "method")
    private String method;

    @Column(name = "status")
    private String status;

    @Column(name = "amount")
    private Double amount;

    @Column(name = "currency")
    private String currency;

    @Column(name = "transaction_id")
    private String transactionId;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    /** Failed Stripe refund attempts so far (null on rows created before refund retries existed). */
    @Column(name = "refund_attempts")
    private Integer refundAttempts = 0;

    @Column(name = "next_refund_at")
    private LocalDateTime nextRefundAt;

    public Payment() {
        this.createdAt = LocalDateTime.now();
    }

    public int getId() { return id; }
    public void setId(int id) { this.id = id; }

    public Order getOrder() { return order; }
    public void setOrder(Order order) { this.order = order; }

    public String getMethod() { return method; }
    public void setMethod(String method) { this.method = method; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public Double getAmount() { return amount; }
    public void setAmount(Double amount) { this.amount = amount; }

    public String getCurrency() { return currency; }
    public void setCurrency(String currency) { this.currency = currency; }

    public String getTransactionId() { return transactionId; }
    public void setTransactionId(String transactionId) { this.transactionId = transactionId; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public int getRefundAttempts() { return refundAttempts == null ? 0 : refundAttempts; }
    public void setRefundAttempts(int refundAttempts) { this.refundAttempts = refundAttempts; }

    public LocalDateTime getNextRefundAt() { return nextRefundAt; }
    public void setNextRefundAt(LocalDateTime nextRefundAt) { this.nextRefundAt = nextRefundAt; }
}
