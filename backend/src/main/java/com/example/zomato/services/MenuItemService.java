package com.example.zomato.services;

import com.example.zomato.entity.MenuItem;
import com.example.zomato.repository.MenuItemRepository;
import com.example.zomato.search.SearchIndexService;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class MenuItemService {

    private final MenuItemRepository repository;
    private final SearchIndexService searchIndex;

    public MenuItemService(MenuItemRepository repository, SearchIndexService searchIndex) {
        this.repository = repository;
        this.searchIndex = searchIndex;
    }

    /** Saves a dish and makes it searchable right away (owner flavor tags if sent, automatic suggestions otherwise). */
    public MenuItem save(MenuItem menuItem) {
        List<String> ownerTags = SearchIndexService.validateOwnerInput(menuItem);
        MenuItem saved = repository.save(menuItem);
        searchIndex.onSaved(saved, ownerTags);
        return saved;
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
        searchIndex.onDeleted(id);
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
        existing.setSpiceLevel(updated.getSpiceLevel());
        existing.setServingTemp(updated.getServingTemp());
        existing.setIngredients(updated.getIngredients());
        existing.setMood(updated.getMood());
        existing.setFlavorTags(updated.getFlavorTags());
        List<String> ownerTags = SearchIndexService.validateOwnerInput(existing);
        MenuItem saved = repository.save(existing);
        searchIndex.onSaved(saved, ownerTags);
        return saved;
    }

    public void updatePrice(int itemId, float price) {
        MenuItem item = getById(itemId);
        item.setPrice(price);
        searchIndex.onChanged(repository.save(item));
    }

    public void toggleAvailability(int itemId) {
        MenuItem item = getById(itemId);
        item.setIsAvailable(
                item.getIsAvailable() == null ? true : !item.getIsAvailable()
        );
        searchIndex.onChanged(repository.save(item));
    }
}
