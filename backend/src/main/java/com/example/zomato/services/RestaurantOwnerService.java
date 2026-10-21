package com.example.zomato.services;

import com.example.zomato.entity.Restaurant;
import com.example.zomato.entity.RestaurantOwner;
import com.example.zomato.repository.RestaurantOwnerRepository;
import com.example.zomato.repository.RestaurantRepository;

import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class RestaurantOwnerService {

    private final RestaurantOwnerRepository restaurantOwnerRepository;
    private final RestaurantRepository restaurantRepository;

    public RestaurantOwnerService(RestaurantOwnerRepository restaurantOwnerRepository,
                                  RestaurantRepository restaurantRepository) {
        this.restaurantOwnerRepository = restaurantOwnerRepository;
        this.restaurantRepository = restaurantRepository;
    }

    public List<RestaurantOwner> getAllOwners() {
        return restaurantOwnerRepository.findAll();
    }

    public RestaurantOwner getOwnerById(int id) {
        return restaurantOwnerRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Owner not found with id: " + id));
    }

    public RestaurantOwner createOwner(RestaurantOwner owner) {
        return restaurantOwnerRepository.save(owner);
    }

    public RestaurantOwner updateOwner(int id, RestaurantOwner updated) {
        RestaurantOwner existing = getOwnerById(id);
        existing.setOwnerName(updated.getOwnerName());
        existing.setEmail(updated.getEmail());
        existing.setPhone(updated.getPhone());
        return restaurantOwnerRepository.save(existing);
    }

    public void deleteOwner(int id) {
        restaurantOwnerRepository.deleteById(id);
    }

    public void addRestaurant(int ownerId, int restaurantId) {
        RestaurantOwner owner = getOwnerById(ownerId);
        Restaurant restaurant = restaurantRepository.findById(restaurantId)
                .orElseThrow(() -> new RuntimeException("Restaurant not found"));
        restaurant.setOwner(owner);
        restaurantRepository.save(restaurant);
    }

    public void removeRestaurant(int restaurantId) {
        Restaurant restaurant = restaurantRepository.findById(restaurantId)
                .orElseThrow(() -> new RuntimeException("Restaurant not found"));
        restaurant.setOwner(null);
        restaurantRepository.save(restaurant);
    }

    public void manageRestaurant(int restaurantId) {
        Restaurant restaurant = restaurantRepository.findById(restaurantId)
                .orElseThrow(() -> new RuntimeException("Restaurant not found"));
        restaurant.setOpen(
                restaurant.getOpen() == null ? true : !restaurant.getOpen()
        );
        restaurantRepository.save(restaurant);
    }

    public List<Restaurant> getOwnerRestaurants(int ownerId) {
        return restaurantRepository.findAll()
                .stream()
                .filter(r -> r.getOwner() != null && r.getOwner().getOwnerId() == ownerId)
                .collect(Collectors.toList());
    }
}
