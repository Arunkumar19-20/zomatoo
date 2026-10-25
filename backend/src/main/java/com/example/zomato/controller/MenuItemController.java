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
    private final com.example.zomato.services.DishImageService images;

    public MenuItemController(MenuItemService service, com.example.zomato.security.OwnershipService ownership, com.example.zomato.services.DishImageService images) {
        this.images = images;
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

    /** Uploads (or replaces) a dish's photo: JPEG, PNG or WebP up to 2 MB, by the owner of that dish's restaurant. Returns the dish with its new imageUrl. */
    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @PostMapping(path = "/{id}/image", consumes = org.springframework.http.MediaType.MULTIPART_FORM_DATA_VALUE)
    public MenuItem uploadImage(@PathVariable int id, @org.springframework.web.bind.annotation.RequestParam("file") org.springframework.web.multipart.MultipartFile file,
                                org.springframework.security.core.Authentication auth) throws java.io.IOException {
        ownership.requireMenuItem(auth, id);
        String url = images.store(file.getBytes());
        return service.setImage(id, url, images);
    }

    /** Removes a dish's photo (the app then shows its picture stand-in again). */
    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @DeleteMapping("/{id}/image")
    public MenuItem removeImage(@PathVariable int id, org.springframework.security.core.Authentication auth) {
        ownership.requireMenuItem(auth, id);
        return service.setImage(id, null, images);
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @PutMapping("/{id}/toggle")
    public void toggleAvailability(@PathVariable int id, org.springframework.security.core.Authentication auth) {
        ownership.requireMenuItem(auth, id);
        service.toggleAvailability(id);
    }
}
