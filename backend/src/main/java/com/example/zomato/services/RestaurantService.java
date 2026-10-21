package com.example.zomato.services;

import com.example.zomato.dto.MenuCategoryDTO;
import com.example.zomato.dto.MenuItemDTO;
import com.example.zomato.dto.RestaurantDTO;
import com.example.zomato.entity.MenuCategory;
import com.example.zomato.entity.MenuItem;
import com.example.zomato.entity.Restaurant;
import com.example.zomato.repository.MenuCategoryRepository;
import com.example.zomato.repository.MenuItemRepository;
import com.example.zomato.repository.RestaurantRepository;
import com.example.zomato.specification.RestaurantSpecification;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.ArrayList;
import java.util.List;

@Service
public class RestaurantService {

    private final RestaurantRepository restaurantRepository;
    private final MenuItemRepository menuItemRepository;
    private final MenuCategoryRepository menuCategoryRepository;

    public RestaurantService(RestaurantRepository restaurantRepository,
                             MenuItemRepository menuItemRepository,
                             MenuCategoryRepository menuCategoryRepository) {
        this.restaurantRepository = restaurantRepository;
        this.menuItemRepository = menuItemRepository;
        this.menuCategoryRepository = menuCategoryRepository;
    }

    public Page<RestaurantDTO> getRestaurants(String cuisine, Float minRating, Boolean isOpen, String search, Pageable pageable) {
        Specification<Restaurant> spec = RestaurantSpecification.withFilters(cuisine, minRating, isOpen, search);
        Page<Restaurant> page = restaurantRepository.findAll(spec, pageable);
        return page.map(RestaurantDTO::new);
    }

    public List<RestaurantDTO> getAllRestaurantDtos() {
        return restaurantRepository.findAll().stream().map(RestaurantDTO::new).toList();
    }

    public Restaurant getRestaurantById(int id) {
        return restaurantRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Restaurant not found with id: " + id));
    }

    public RestaurantDTO getRestaurantDtoById(int id) {
        return new RestaurantDTO(getRestaurantById(id));
    }

    public List<MenuCategoryDTO> getRestaurantMenu(int restaurantId) {
        if (!restaurantRepository.existsById(restaurantId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Restaurant not found with id: " + restaurantId);
        }
        List<MenuCategory> categories = menuCategoryRepository.findCategoriesWithItemsByRestaurantId(restaurantId);
        return categories.stream().map(cat -> {
            List<MenuItemDTO> items = cat.getItems() != null
                    ? cat.getItems().stream().map(MenuItemDTO::new).toList()
                    : new ArrayList<>();
            return new MenuCategoryDTO(cat.getId(), cat.getName(), items);
        }).toList();
    }

    public RestaurantDTO createRestaurant(Restaurant restaurant) {
        return new RestaurantDTO(restaurantRepository.save(restaurant));
    }

    public RestaurantDTO updateRestaurant(int id, Restaurant updated) {
        Restaurant existing = getRestaurantById(id);
        existing.setName(updated.getName());
        existing.setAddress(updated.getAddress());
        existing.setRating(updated.getRating());
        existing.setOpen(updated.getOpen());
        existing.setOpeningHours(updated.getOpeningHours());
        existing.setDeliveryTime(updated.getDeliveryTime());
        existing.setLocation(updated.getLocation());
        existing.setCuisine(updated.getCuisine());
        existing.setDiscount(updated.getDiscount());
        existing.setImageUrl(updated.getImageUrl());
        return new RestaurantDTO(restaurantRepository.save(existing));
    }

    public void deleteRestaurant(int id) {
        if (!restaurantRepository.existsById(id)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Restaurant not found with id: " + id);
        }
        restaurantRepository.deleteById(id);
    }

    public List<RestaurantDTO> getByLocation(Integer locationId) {
        return restaurantRepository.findByLocationId(locationId).stream().map(RestaurantDTO::new).toList();
    }

    public List<RestaurantDTO> getOpenRestaurants() {
        return restaurantRepository.findByIsOpenTrue().stream().map(RestaurantDTO::new).toList();
    }

    public List<RestaurantDTO> getByMinRating(float rating) {
        return restaurantRepository.findByRatingGreaterThanEqual(rating).stream().map(RestaurantDTO::new).toList();
    }

    public List<RestaurantDTO> getByOwner(Integer ownerId) {
        return restaurantRepository.findByOwner_OwnerId(ownerId).stream().map(RestaurantDTO::new).toList();
    }

    public void updateStatus(int restaurantId, Boolean isOpen) {
        Restaurant restaurant = getRestaurantById(restaurantId);
        restaurant.setOpen(isOpen);
        restaurantRepository.save(restaurant);
    }

    public void addMenuItem(MenuItem item) {
        menuItemRepository.save(item);
    }

    public void removeMenuItem(int itemId) {
        menuItemRepository.deleteById(itemId);
    }
}
