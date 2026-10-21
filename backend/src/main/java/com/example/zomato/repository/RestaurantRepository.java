package com.example.zomato.repository;

import com.example.zomato.entity.Restaurant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface RestaurantRepository extends JpaRepository<Restaurant, Integer>, JpaSpecificationExecutor<Restaurant> {

    List<Restaurant> findByLocationId(Integer locationId);

    
    List<Restaurant> findByOwner_OwnerId(Integer ownerId);

   
    List<Restaurant> findByIsOpenTrue();

    List<Restaurant> findByRatingGreaterThanEqual(float rating);
}