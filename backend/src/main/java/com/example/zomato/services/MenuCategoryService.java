package com.example.zomato.services;

import com.example.zomato.entity.MenuCategory;
import com.example.zomato.entity.Restaurant;
import com.example.zomato.entity.MenuItem;
import com.example.zomato.repository.MenuCategoryRepository;
import com.example.zomato.repository.RestaurantRepository;
import com.example.zomato.repository.MenuItemRepository;

import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class MenuCategoryService {

    private final MenuCategoryRepository menuCategoryRepository;
    private final RestaurantRepository restaurantRepository;
    private final MenuItemRepository menuItemRepository;

    public MenuCategoryService(MenuCategoryRepository menuCategoryRepository,
                               RestaurantRepository restaurantRepository,
                               MenuItemRepository menuItemRepository) {
        this.menuCategoryRepository = menuCategoryRepository;
        this.restaurantRepository = restaurantRepository;
        this.menuItemRepository = menuItemRepository;
    }

    public List<MenuCategory> getAllCategories() {
        return menuCategoryRepository.findAll();
    }

    public MenuCategory getCategoryById(int id) {
        return menuCategoryRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("MenuCategory not found with id: " + id));
    }

    public List<MenuCategory> getCategoriesByRestaurant(int restaurantId) {
        return menuCategoryRepository.findByRestaurantIdOrderByDisplayOrderAsc(restaurantId);
    }

    public MenuCategory createCategory(int restaurantId, MenuCategory category) {
        Restaurant restaurant = restaurantRepository.findById(restaurantId)
                .orElseThrow(() -> new RuntimeException("Restaurant not found with id: " + restaurantId));
        if (menuCategoryRepository.existsByNameAndRestaurantId(category.getName(), restaurantId)) {
            throw new RuntimeException("Category already exists: " + category.getName());
        }
        category.setRestaurant(restaurant);
        return menuCategoryRepository.save(category);
    }

    public MenuCategory updateCategory(int id, MenuCategory updated) {
        MenuCategory existing = getCategoryById(id);
        existing.setName(updated.getName());
        existing.setDisplayOrder(updated.getDisplayOrder());
        return menuCategoryRepository.save(existing);
    }

    public void deleteCategory(int id) {
        menuCategoryRepository.deleteById(id);
    }

    public void addItem(MenuItem item) {
        menuItemRepository.save(item);
    }

    public void removeItem(int itemId) {
        menuItemRepository.deleteById(itemId);
    }
}
