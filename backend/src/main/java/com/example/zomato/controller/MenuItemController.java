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

    public MenuItemController(MenuItemService service) {
        this.service = service;
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @PostMapping
    public MenuItem save(@RequestBody MenuItem item) {
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
    public void delete(@PathVariable int id) {
        service.delete(id);
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @PutMapping("/{id}")
    public MenuItem update(@PathVariable int id, @RequestBody MenuItem item) {
        return service.update(id, item);
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @PutMapping("/{id}/price")
    public void updatePrice(@PathVariable int id, @RequestParam float price) {
        service.updatePrice(id, price);
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @PutMapping("/{id}/toggle")
    public void toggleAvailability(@PathVariable int id) {
        service.toggleAvailability(id);
    }
}
