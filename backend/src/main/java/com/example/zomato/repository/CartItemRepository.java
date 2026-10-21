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
}

