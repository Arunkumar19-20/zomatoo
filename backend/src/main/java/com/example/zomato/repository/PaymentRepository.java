package com.example.zomato.repository;

import com.example.zomato.entity.Payment;
import org.springframework.data.jpa.repository.JpaRepository;

import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface PaymentRepository extends JpaRepository<Payment, Integer> {
    Optional<Payment> findByTransactionId(String transactionId);
    Optional<Payment> findByOrder_OrderId(int orderId);

    /** Failed refunds whose back-off has elapsed and that still have attempts left. */
    @Query("select p from Payment p where p.status = 'REFUND_FAILED' " +
           "and (p.nextRefundAt is null or p.nextRefundAt <= :now) " +
           "and (p.refundAttempts is null or p.refundAttempts < :maxAttempts)")
    List<Payment> findDueRefundRetries(@Param("now") LocalDateTime now, @Param("maxAttempts") int maxAttempts);

    List<Payment> findByStatus(String status);
}
