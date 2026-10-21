package com.example.zomato.controller;

import com.example.zomato.entity.OrderCoupon;
import com.example.zomato.services.OrderCouponService;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/order-coupon")
public class OrderCouponController {

    private final OrderCouponService service;

    public OrderCouponController(OrderCouponService service) {
        this.service = service;
    }

    @PostMapping
    public OrderCoupon create(@RequestBody OrderCoupon oc) {
        return service.save(oc);
    }

    @GetMapping
    public List<OrderCoupon> getAll() {
        return service.getAll();
    }

    @GetMapping("/{orderId}/{couponId}")
    public OrderCoupon getById(@PathVariable int orderId, @PathVariable int couponId) {
        return service.getById(orderId, couponId);
    }

    @DeleteMapping("/{orderId}/{couponId}")
    public String delete(@PathVariable int orderId, @PathVariable int couponId) {
        service.delete(orderId, couponId);
        return "Deleted successfully";
    }
}
