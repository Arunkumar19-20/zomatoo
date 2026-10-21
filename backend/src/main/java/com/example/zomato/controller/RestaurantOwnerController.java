package com.example.zomato.controller;

import com.example.zomato.entity.Restaurant;
import com.example.zomato.entity.RestaurantOwner;
import com.example.zomato.services.RestaurantOwnerService;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/owners")
public class RestaurantOwnerController {

    private final RestaurantOwnerService service;

    public RestaurantOwnerController(RestaurantOwnerService service) {
        this.service = service;
    }

    @GetMapping
    public List<RestaurantOwner> getAll() {
        return service.getAllOwners();
    }

    @GetMapping("/{id}")
    public RestaurantOwner getById(@PathVariable int id) {
        return service.getOwnerById(id);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping
    public RestaurantOwner create(@RequestBody RestaurantOwner owner) {
        return service.createOwner(owner);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PutMapping("/{id}")
    public RestaurantOwner update(@PathVariable int id, @RequestBody RestaurantOwner owner) {
        return service.updateOwner(id, owner);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @DeleteMapping("/{id}")
    public void delete(@PathVariable int id) {
        service.deleteOwner(id);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/{ownerId}/add-restaurant/{restaurantId}")
    public void addRestaurant(@PathVariable int ownerId, @PathVariable int restaurantId) {
        service.addRestaurant(ownerId, restaurantId);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @DeleteMapping("/{ownerId}/remove-restaurant/{restaurantId}")
    public void removeRestaurant(@PathVariable int ownerId, @PathVariable int restaurantId) {
        service.removeRestaurant(restaurantId);
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @PutMapping("/manage/{restaurantId}")
    public void manageRestaurant(@PathVariable int restaurantId) {
        service.manageRestaurant(restaurantId);
    }

    @GetMapping("/{ownerId}/restaurants")
    public List<Restaurant> getOwnerRestaurants(@PathVariable int ownerId) {
        return service.getOwnerRestaurants(ownerId);
    }
}
