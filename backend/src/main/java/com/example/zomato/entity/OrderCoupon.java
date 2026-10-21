package com.example.zomato.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;

import java.io.Serializable;
import java.util.Objects;

@Entity
@Table(name = "order_coupon")
@IdClass(OrderCoupon.OrderCouponId.class)
public class OrderCoupon {

    @Id
    @Column(name = "order_id")
    private int orderId;

    @Id
    @Column(name = "coupon_id")
    private int couponId;

    // 🔥 Break recursion
    @ManyToOne
    @JoinColumn(name = "order_id", insertable = false, updatable = false)
    @JsonIgnore
    private Order order;

    // 🔥 Break recursion
    @ManyToOne
    @JoinColumn(name = "coupon_id", insertable = false, updatable = false)
    @JsonIgnore
    private Coupon coupon;

    public OrderCoupon() {}

    public OrderCoupon(int orderId, int couponId) {
        this.orderId = orderId;
        this.couponId = couponId;
    }

    public int getOrderId() { return orderId; }
    public void setOrderId(int orderId) { this.orderId = orderId; }

    public int getCouponId() { return couponId; }
    public void setCouponId(int couponId) { this.couponId = couponId; }

    // ✅ Composite Key
    public static class OrderCouponId implements Serializable {
        private int orderId;
        private int couponId;

        public OrderCouponId() {}

        public OrderCouponId(int orderId, int couponId) {
            this.orderId = orderId;
            this.couponId = couponId;
        }

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof OrderCouponId)) return false;
            OrderCouponId that = (OrderCouponId) o;
            return orderId == that.orderId && couponId == that.couponId;
        }

        @Override
        public int hashCode() {
            return Objects.hash(orderId, couponId);
        }
    }
}