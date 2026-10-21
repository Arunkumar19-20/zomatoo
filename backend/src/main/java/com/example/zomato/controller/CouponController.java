package com.example.zomato.controller;

import com.example.zomato.entity.Coupon;
import com.example.zomato.services.CouponService;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/coupon")
public class CouponController {

    private final CouponService couponService;

    public CouponController(CouponService couponService) {
        this.couponService = couponService;
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping
    public Coupon createCoupon(@RequestBody Coupon coupon) {
        return couponService.saveCoupon(coupon);
    }

    @GetMapping
    public List<Coupon> getAllCoupons() {
        return couponService.getAllCoupons();
    }

    @GetMapping("/active")
    public List<Coupon> getActiveCoupons() {
        return couponService.getActiveCoupons();
    }

    @PostMapping("/apply")
    public String applyCoupon(@RequestParam String code, @RequestParam int orderId) {
        float discount = couponService.applyCoupon(code, orderId);
        return "Coupon applied! Discount = " + discount;
    }
}
