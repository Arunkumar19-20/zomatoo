package com.example.zomato.controller;

import com.example.zomato.entity.MenuItem;
import com.example.zomato.services.MenuItemService;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/menu-items")
public class MenuItemController {

    private final MenuItemService service;
    private final com.example.zomato.security.OwnershipService ownership;

    public MenuItemController(MenuItemService service, com.example.zomato.security.OwnershipService ownership) {
        this.ownership = ownership;
        this.service = service;
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @PostMapping
    public MenuItem save(@RequestBody MenuItem item, org.springframework.security.core.Authentication auth) {
        ownership.requireCategoryOf(auth, item);
        return service.save(item);
    }

    @GetMapping
    public List<MenuItem> getAll() {
        return service.getAll();
    }

    @GetMapping("/{id}")
    public MenuItem getById(@PathVariable int id) {
        return service.getById(id);
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @DeleteMapping("/{id}")
    public void delete(@PathVariable int id, org.springframework.security.core.Authentication auth) {
        ownership.requireMenuItem(auth, id);
        service.delete(id);
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @PutMapping("/{id}")
    public MenuItem update(@PathVariable int id, @RequestBody MenuItem item, org.springframework.security.core.Authentication auth) {
        ownership.requireMenuItem(auth, id);
        if (item.getCategory() != null && item.getCategory().getId() != null) ownership.requireCategoryOf(auth, item);   // and not moved into someone else's menu
        return service.update(id, item);
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @PutMapping("/{id}/price")
    public void updatePrice(@PathVariable int id, @RequestParam float price, org.springframework.security.core.Authentication auth) {
        ownership.requireMenuItem(auth, id);
        service.updatePrice(id, price);
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @PutMapping("/{id}/toggle")
    public void toggleAvailability(@PathVariable int id, org.springframework.security.core.Authentication auth) {
        ownership.requireMenuItem(auth, id);
        service.toggleAvailability(id);
    }
}
