package com.example.zomato.repository;

import com.example.zomato.entity.CartItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

public interface CartItemRepository extends JpaRepository<CartItem, Integer> {

    List<CartItem> findByCartId(Integer cartId);

    java.util.Optional<CartItem> findByCartIdAndItem_Id(Integer cartId, Integer itemId);

    @Transactional
    void deleteByCartId(Integer cartId);

    /** Forgets which search led to a cart item once the attribution window has passed. */
    @Transactional
    @org.springframework.data.jpa.repository.Modifying
    @org.springframework.data.jpa.repository.Query("update CartItem c set c.searchAttribution = null, c.searchAttributionAt = null where c.searchAttributionAt < :cutoff")
    int clearAttributionOlderThan(@org.springframework.data.repository.query.Param("cutoff") java.time.LocalDateTime cutoff);
}
