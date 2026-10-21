package com.example.zomato.repository;

import com.example.zomato.entity.OrderCoupon;
import com.example.zomato.entity.OrderCoupon.OrderCouponId;
import org.springframework.data.jpa.repository.JpaRepository;

public interface OrderCouponRepository
        extends JpaRepository<OrderCoupon, OrderCouponId> {
}