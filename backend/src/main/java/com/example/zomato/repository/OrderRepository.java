package com.example.zomato.repository;

import com.example.zomato.entity.Order;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface OrderRepository extends JpaRepository<Order, Integer> {
    List<Order> findByCustomer_CustomerId(Integer customerId);
    List<Order> findByCustomer_Email(String email);
    Optional<Order> findByOrderIdAndCustomer_Email(int orderId, String email);
}