package com.example.zomato.services;

import com.example.zomato.entity.OrderCoupon;
import com.example.zomato.entity.OrderCoupon.OrderCouponId;
import com.example.zomato.repository.OrderCouponRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class OrderCouponService {

    private final OrderCouponRepository repository;

    public OrderCouponService(OrderCouponRepository repository) {
        this.repository = repository;
    }

    public OrderCoupon save(OrderCoupon oc) {
        return repository.save(oc);
    }

    public List<OrderCoupon> getAll() {
        return repository.findAll();
    }

    public OrderCoupon getById(int orderId, int couponId) {
        return repository.findById(new OrderCouponId(orderId, couponId))
                .orElseThrow(() -> new RuntimeException("Not found"));
    }

    public void delete(int orderId, int couponId) {
        repository.deleteById(new OrderCouponId(orderId, couponId));
    }
}
