package com.example.zomato.controller;

import com.example.zomato.dto.MenuCategoryDTO;
import com.example.zomato.dto.RestaurantDTO;
import com.example.zomato.entity.MenuItem;
import com.example.zomato.entity.Restaurant;
import com.example.zomato.services.RestaurantService;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/restaurants")
public class RestaurantController {

    private final RestaurantService service;
    private final com.example.zomato.security.OwnershipService ownership;

    public RestaurantController(RestaurantService service, com.example.zomato.security.OwnershipService ownership) {
        this.ownership = ownership;
        this.service = service;
    }

    @GetMapping
    public Page<RestaurantDTO> getAll(
            @RequestParam(required = false) String cuisine,
            @RequestParam(required = false) Float minRating,
            @RequestParam(required = false) Boolean isOpen,
            @RequestParam(required = false) String search,
            @PageableDefault(size = 20, sort = "id", direction = Sort.Direction.ASC) Pageable pageable) {
        return service.getRestaurants(cuisine, minRating, isOpen, search, pageable);
    }

    @GetMapping("/{id}")
    public RestaurantDTO getById(@PathVariable int id) {
        return service.getRestaurantDtoById(id);
    }

    @GetMapping("/{id}/menu")
    public List<MenuCategoryDTO> getMenu(@PathVariable int id) {
        return service.getRestaurantMenu(id);
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @PostMapping
    public RestaurantDTO create(@RequestBody Restaurant restaurant, org.springframework.security.core.Authentication auth) {
        // an owner can only create a restaurant under their own owner record, never under someone else's or none
        if (!ownership.isAdmin(auth)) restaurant.setOwner(ownership.ownerRecordOf(auth));
        return service.createRestaurant(restaurant);
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @PutMapping("/{id}")
    public RestaurantDTO update(@PathVariable int id, @RequestBody Restaurant restaurant, org.springframework.security.core.Authentication auth) {
        ownership.requireRestaurant(auth, id);
        return service.updateRestaurant(id, restaurant);
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @DeleteMapping("/{id}")
    public void delete(@PathVariable int id, org.springframework.security.core.Authentication auth) {
        ownership.requireRestaurant(auth, id);
        service.deleteRestaurant(id);
    }

    @GetMapping("/location/{locationId}")
    public List<RestaurantDTO> getByLocation(@PathVariable Integer locationId) {
        return service.getByLocation(locationId);
    }

    @GetMapping("/open")
    public List<RestaurantDTO> getOpenRestaurants() {
        return service.getOpenRestaurants();
    }

    @GetMapping("/rating/{rating}")
    public List<RestaurantDTO> getByRating(@PathVariable float rating) {
        return service.getByMinRating(rating);
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @PutMapping("/{id}/status")
    public void updateStatus(@PathVariable int id, @RequestParam Boolean isOpen, org.springframework.security.core.Authentication auth) {
        ownership.requireRestaurant(auth, id);
        service.updateStatus(id, isOpen);
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @PostMapping("/menu-item")
    public void addMenuItem(@RequestBody MenuItem item, org.springframework.security.core.Authentication auth) {
        ownership.requireCategoryOf(auth, item);
        service.addMenuItem(item);
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @DeleteMapping("/menu-item/{itemId}")
    public void removeMenuItem(@PathVariable int itemId, org.springframework.security.core.Authentication auth) {
        ownership.requireMenuItem(auth, itemId);
        service.removeMenuItem(itemId);
    }
}
