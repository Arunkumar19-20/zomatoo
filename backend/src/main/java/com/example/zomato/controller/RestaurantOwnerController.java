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
    private final com.example.zomato.security.OwnershipService ownership;

    public RestaurantOwnerController(RestaurantOwnerService service, com.example.zomato.security.OwnershipService ownership) {
        this.ownership = ownership;
        this.service = service;
    }

    /** Every owner's name, email and phone: admins only. */
    @PreAuthorize("hasRole('ADMIN')")
    @GetMapping
    public List<RestaurantOwner> getAll() {
        return service.getAllOwners();
    }

    @GetMapping("/{id}")
    public RestaurantOwner getById(@PathVariable int id, org.springframework.security.core.Authentication auth) {
        requireAdminOrSelf(auth, id);
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
    public void manageRestaurant(@PathVariable int restaurantId, org.springframework.security.core.Authentication auth) {
        ownership.requireRestaurant(auth, restaurantId);
        service.manageRestaurant(restaurantId);
    }

    @GetMapping("/{ownerId}/restaurants")
    public List<Restaurant> getOwnerRestaurants(@PathVariable int ownerId, org.springframework.security.core.Authentication auth) {
        requireAdminOrSelf(auth, ownerId);
        return service.getOwnerRestaurants(ownerId);
    }

    /** An owner's profile and restaurants are for that owner and for admins, not for every signed-in customer. */
    private void requireAdminOrSelf(org.springframework.security.core.Authentication auth, int ownerId) {
        if (!ownership.isAdmin(auth) && !ownership.isSelf(auth, ownerId)) {
            throw new org.springframework.web.server.ResponseStatusException(org.springframework.http.HttpStatus.FORBIDDEN, "Not your profile.");
        }
    }
}
