package com.example.zomato.repository;

import com.example.zomato.entity.DeliveryRating;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface DeliveryRatingRepository extends JpaRepository<DeliveryRating, Integer> {

    List<DeliveryRating> findByDeliveryPartner_Id(int partnerId);

    List<DeliveryRating> findByOrder_OrderId(int orderId);
}