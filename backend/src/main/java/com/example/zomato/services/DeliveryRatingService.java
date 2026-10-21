package com.example.zomato.services;

import com.example.zomato.entity.DeliveryRating;

import java.util.List;

public interface DeliveryRatingService {

    DeliveryRating submitRating(DeliveryRating rating);

    List<DeliveryRating> getAllRatings();

    List<DeliveryRating> getRatingsByPartnerId(Integer partnerId);

    List<DeliveryRating> getRatingsByOrderId(Integer orderId);
}