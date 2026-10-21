package com.example.zomato.services.impl;

import com.example.zomato.entity.DeliveryPartner;
import com.example.zomato.entity.DeliveryRating;
import com.example.zomato.repository.DeliveryPartnerRepository;
import com.example.zomato.repository.DeliveryRatingRepository;
import com.example.zomato.repository.OrderRepository;
import com.example.zomato.services.DeliveryRatingService;

import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class DeliveryRatingServiceImpl implements DeliveryRatingService {

    private final DeliveryRatingRepository repository;
    private final DeliveryPartnerRepository deliveryPartnerRepository;
    private final OrderRepository orderRepository;

    public DeliveryRatingServiceImpl(DeliveryRatingRepository repository,
                                     DeliveryPartnerRepository deliveryPartnerRepository,
                                     OrderRepository orderRepository) {
        this.repository = repository;
        this.deliveryPartnerRepository = deliveryPartnerRepository;
        this.orderRepository = orderRepository;
    }

    @Override
    public DeliveryRating submitRating(DeliveryRating rating) {
        DeliveryPartner partner = deliveryPartnerRepository
                .findById(rating.getDeliveryPartnerId())
                .orElseThrow(() -> new RuntimeException("Partner not found"));

        com.example.zomato.entity.Order order = orderRepository
                .findById(rating.getOrderId())
                .orElseThrow(() -> new RuntimeException("Order not found"));

        rating.setDeliveryPartner(partner);
        rating.setOrder(order);
        rating.setTimestamp(java.time.LocalDateTime.now());

        return repository.save(rating);
    }

    @Override
    public List<DeliveryRating> getAllRatings() {
        return repository.findAll();
    }

    @Override
    public List<DeliveryRating> getRatingsByPartnerId(Integer partnerId) {
        return repository.findByDeliveryPartner_Id(partnerId);
    }

    @Override
    public List<DeliveryRating> getRatingsByOrderId(Integer orderId) {
        return repository.findByOrder_OrderId(orderId);
    }
}
