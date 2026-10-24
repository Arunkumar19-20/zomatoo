package com.example.zomato.repository;

import com.example.zomato.entity.MenuItemEmbedding;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MenuItemEmbeddingRepository extends JpaRepository<MenuItemEmbedding, Integer> {
}
