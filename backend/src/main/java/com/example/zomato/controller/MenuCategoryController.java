package com.example.zomato.controller;

import com.example.zomato.entity.MenuCategory;
import com.example.zomato.entity.MenuItem;
import com.example.zomato.services.MenuCategoryService;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/categories")
public class MenuCategoryController {

    private final MenuCategoryService service;

    public MenuCategoryController(MenuCategoryService service) {
        this.service = service;
    }

    @GetMapping
    public List<MenuCategory> getAll() {
        return service.getAllCategories();
    }

    @GetMapping("/{id}")
    public MenuCategory getById(@PathVariable int id) {
        return service.getCategoryById(id);
    }

    @GetMapping("/restaurant/{restaurantId}")
    public List<MenuCategory> getByRestaurant(@PathVariable int restaurantId) {
        return service.getCategoriesByRestaurant(restaurantId);
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @PostMapping("/{restaurantId}")
    public MenuCategory create(@PathVariable int restaurantId, @RequestBody MenuCategory category) {
        return service.createCategory(restaurantId, category);
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @PutMapping("/{id}")
    public MenuCategory update(@PathVariable int id, @RequestBody MenuCategory category) {
        return service.updateCategory(id, category);
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @DeleteMapping("/{id}")
    public void delete(@PathVariable int id) {
        service.deleteCategory(id);
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @PostMapping("/add-item")
    public void addItem(@RequestBody MenuItem item) {
        service.addItem(item);
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @DeleteMapping("/remove-item/{itemId}")
    public void removeItem(@PathVariable int itemId) {
        service.removeItem(itemId);
    }
}

