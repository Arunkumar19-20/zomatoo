package com.example.zomato.repository;

import com.example.zomato.entity.RestaurantOwner;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface RestaurantOwnerRepository extends JpaRepository<RestaurantOwner, Integer> {

    /** A signed-in owner is linked to their owner record by email address. */
    java.util.List<RestaurantOwner> findByEmailIgnoreCase(String email);
}