package com.example.zomato.services;

import com.example.zomato.entity.MenuItem;
import com.example.zomato.repository.MenuItemRepository;
import com.example.zomato.search.SearchIndexService;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@Service
public class MenuItemService {

    private final MenuItemRepository repository;
    private final SearchIndexService searchIndex;
    private final DishImageService images;

    public MenuItemService(MenuItemRepository repository, SearchIndexService searchIndex, DishImageService images) {
        this.images = images;
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
        // a deleted dish takes its uploaded photo with it
        repository.findById(id).ifPresent(i -> { if (images != null) images.deleteIfOurs(i.getImageUrl()); });
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

    /** Sets (or clears, with null) a dish's photo and refreshes the search index; the replaced photo file is deleted if it was an upload. */
    public MenuItem setImage(int itemId, String imageUrl, DishImageService images) {
        MenuItem item = repository.findById(itemId).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Menu item not found"));
        String old = item.getImageUrl();
        item.setImageUrl(imageUrl);
        MenuItem saved = repository.save(item);
        searchIndex.onChanged(saved);
        if (old != null && !old.equals(imageUrl)) images.deleteIfOurs(old);
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
