package com.example.zomato.services;

import com.example.zomato.entity.Coupon;
import com.example.zomato.entity.Order;
import com.example.zomato.repository.CouponRepository;
import com.example.zomato.repository.OrderRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class CouponService {

    private final CouponRepository couponRepository;
    private final OrderRepository orderRepository;

    public CouponService(CouponRepository couponRepository, OrderRepository orderRepository) {
        this.couponRepository = couponRepository;
        this.orderRepository = orderRepository;
    }

    public Coupon saveCoupon(Coupon coupon) {
        return couponRepository.save(coupon);
    }

    public List<Coupon> getAllCoupons() {
        return couponRepository.findAll();
    }

    public List<Coupon> getActiveCoupons() {
        return couponRepository.findAll()
                .stream()
                .filter(Coupon::isActive)
                .toList();
    }

    public float applyCoupon(String code, int orderId) {
        Coupon coupon = couponRepository.findByCode(code)
                .orElseThrow(() -> new RuntimeException("Coupon not found"));

        if (!coupon.isActive()) {
            throw new RuntimeException("Coupon expired or inactive");
        }

        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new RuntimeException("Order not found"));

        float discount;
        if ("PERCENTAGE".equalsIgnoreCase(coupon.getDiscountType())) {
            discount = (float) ((order.getTotalAmount() * coupon.getDiscount()) / 100);
        } else {
            discount = coupon.getDiscount();
        }

        order.setTotalAmount(order.getTotalAmount() - discount);
        orderRepository.save(order);

        return discount;
    }
}
