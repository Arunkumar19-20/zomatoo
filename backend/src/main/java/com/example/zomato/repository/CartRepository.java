package com.example.zomato.repository;

import com.example.zomato.entity.Cart;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface CartRepository extends JpaRepository<Cart, Integer> {
    Optional<Cart> findByCustomer_CustomerId(Integer customerId);
}