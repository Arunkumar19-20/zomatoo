package com.example.zomato.services;

import com.example.zomato.entity.MenuItem;
import com.example.zomato.repository.MenuItemRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class MenuItemService {

    private final MenuItemRepository repository;

    public MenuItemService(MenuItemRepository repository) {
        this.repository = repository;
    }

    public MenuItem save(MenuItem menuItem) {
        return repository.save(menuItem);
    }

    public List<MenuItem> getAll() {
        return repository.findAll();
    }

    public MenuItem getById(int id) {
        return repository.findById(id)
                .orElseThrow(() -> new RuntimeException("MenuItem not found with id: " + id));
    }

    public void delete(int id) {
        repository.deleteById(id);
    }

    public MenuItem update(int id, MenuItem updated) {
        MenuItem existing = getById(id);
        existing.setName(updated.getName());
        existing.setDescription(updated.getDescription());
        existing.setImageUrl(updated.getImageUrl());
        existing.setIsAvailable(updated.getIsAvailable());
        existing.setIsVeg(updated.getIsVeg());
        existing.setPrice(updated.getPrice());
        existing.setCategory(updated.getCategory());
        return repository.save(existing);
    }

    public void updatePrice(int itemId, float price) {
        MenuItem item = getById(itemId);
        item.setPrice(price);
        repository.save(item);
    }

    public void toggleAvailability(int itemId) {
        MenuItem item = getById(itemId);
        item.setIsAvailable(
                item.getIsAvailable() == null ? true : !item.getIsAvailable()
        );
        repository.save(item);
    }
}
