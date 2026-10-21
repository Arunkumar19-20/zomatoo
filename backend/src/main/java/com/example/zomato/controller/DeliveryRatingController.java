package com.example.zomato.controller;

import com.example.zomato.entity.DeliveryRating;
import com.example.zomato.services.DeliveryRatingService;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/ratings")
public class DeliveryRatingController {

    private final DeliveryRatingService service;

    public DeliveryRatingController(DeliveryRatingService service) {
        this.service = service;
    }

    @PostMapping
    public DeliveryRating submitRating(@RequestBody DeliveryRating rating) {
        return service.submitRating(rating);
    }

    @GetMapping
    public List<DeliveryRating> getAllRatings() {
        return service.getAllRatings();
    }

    @GetMapping("/partner/{partnerId}")
    public List<DeliveryRating> getByPartner(@PathVariable Integer partnerId) {
        return service.getRatingsByPartnerId(partnerId);
    }

    @GetMapping("/order/{orderId}")
    public List<DeliveryRating> getByOrder(@PathVariable Integer orderId) {
        return service.getRatingsByOrderId(orderId);
    }
}