package com.example.zomato.repository;

import com.example.zomato.entity.Payment;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface PaymentRepository extends JpaRepository<Payment, Integer> {
    Optional<Payment> findByTransactionId(String transactionId);
    Optional<Payment> findByOrder_OrderId(int orderId);
}

