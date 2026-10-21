package com.example.zomato.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;

import java.time.LocalDateTime;
import java.util.List;

@Entity
@Table(name = "orders")
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int orderId;

    @Column(name = "status")
    private String status;

    @Enumerated(EnumType.STRING)
    @Column(name = "payment_status", columnDefinition = "varchar(20) default 'PENDING'")
    private PaymentStatus paymentStatus = PaymentStatus.PENDING;

    @Column(name = "order_date")
    private LocalDateTime orderDate;

    @Column(name = "total_amount")
    private float totalAmount;

    @ManyToOne
    @JoinColumn(name = "customer_id")
    @JsonIgnore
    private Customer customer;

    @ManyToOne
    @JoinColumn(name = "restaurant_id")
    @JsonIgnore
    private Restaurant restaurant;

    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL)
    @JsonIgnore
    private List<OrderItem> orderItems;

    @OneToMany(mappedBy = "order")
    @JsonIgnore
    private List<OrderCoupon> orderCoupons;

    public int getOrderId() { return orderId; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public PaymentStatus getPaymentStatus() {
        return paymentStatus != null ? paymentStatus : PaymentStatus.PENDING;
    }
    public void setPaymentStatus(PaymentStatus paymentStatus) {
        this.paymentStatus = paymentStatus;
    }

    public LocalDateTime getOrderDate() { return orderDate; }
    public void setOrderDate(LocalDateTime orderDate) { this.orderDate = orderDate; }

    public float getTotalAmount() { return totalAmount; }
    public void setTotalAmount(float totalAmount) { this.totalAmount = totalAmount; }
    public void setTotalAmount(double total) { this.totalAmount = (float) total; }

    public Customer getCustomer() { return customer; }
    public void setCustomer(Customer customer) { this.customer = customer; }

    public Restaurant getRestaurant() { return restaurant; }
    public void setRestaurant(Restaurant restaurant) { this.restaurant = restaurant; }

    public List<OrderItem> getOrderItems() { return orderItems; }
    public void setOrderItems(List<OrderItem> orderItems) { this.orderItems = orderItems; }

    public List<OrderCoupon> getOrderCoupons() { return orderCoupons; }
    public void setOrderCoupons(List<OrderCoupon> orderCoupons) { this.orderCoupons = orderCoupons; }

    public void updateStatus(String status) {
        this.status = status;
    }
}
