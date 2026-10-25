package com.example.zomato.repository;

import com.example.zomato.entity.OrderAttributionPending;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

public interface OrderAttributionPendingRepository extends JpaRepository<OrderAttributionPending, Long> {

    List<OrderAttributionPending> findByOrderId(int orderId);

    @Query("select distinct p.orderId from OrderAttributionPending p")
    List<Integer> pendingOrderIds();

    @Transactional
    @Modifying
    @Query("delete from OrderAttributionPending p where p.orderId = :orderId")
    int deleteForOrder(@Param("orderId") int orderId);
}
