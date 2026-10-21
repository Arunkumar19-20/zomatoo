package com.example.zomato.repository;

import com.example.zomato.entity.MenuCategory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface MenuCategoryRepository extends JpaRepository<MenuCategory, Integer> {

    List<MenuCategory> findByRestaurantId(int restaurantId);

    List<MenuCategory> findByRestaurantIdOrderByDisplayOrderAsc(int restaurantId);

    @org.springframework.data.jpa.repository.Query("SELECT DISTINCT c FROM MenuCategory c LEFT JOIN FETCH c.items WHERE c.restaurant.id = :restaurantId ORDER BY c.displayOrder ASC, c.id ASC")
    List<MenuCategory> findCategoriesWithItemsByRestaurantId(@org.springframework.data.repository.query.Param("restaurantId") int restaurantId);

    boolean existsByNameAndRestaurantId(String name, int restaurantId);
}