package com.example.zomato.security;

import com.example.zomato.entity.Drop;
import com.example.zomato.entity.MenuCategory;
import com.example.zomato.entity.MenuItem;
import com.example.zomato.entity.Restaurant;
import com.example.zomato.entity.RestaurantOwner;
import com.example.zomato.repository.DropRepository;
import com.example.zomato.repository.MenuCategoryRepository;
import com.example.zomato.repository.MenuItemRepository;
import com.example.zomato.repository.RestaurantOwnerRepository;
import com.example.zomato.repository.RestaurantRepository;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * Who may change which restaurant's things. Having the OWNER role is not enough: an owner may only touch the restaurants whose owner record carries
 * their own email address. An admin may touch anything. Every endpoint that changes a restaurant, its menu or its Drops asks here first, with the
 * restaurant worked out on the server (from the dish, category or Drop in question), never trusted from the request.
 */
@Service
public class OwnershipService {

    private static final String DENIED = "You can only manage your own restaurant.";

    private final RestaurantRepository restaurants;
    private final RestaurantOwnerRepository owners;
    private final MenuItemRepository items;
    private final MenuCategoryRepository categories;
    private final DropRepository drops;

    public OwnershipService(RestaurantRepository restaurants, RestaurantOwnerRepository owners, MenuItemRepository items,
                            MenuCategoryRepository categories, DropRepository drops) {
        this.restaurants = restaurants;
        this.owners = owners;
        this.items = items;
        this.categories = categories;
        this.drops = drops;
    }

    public boolean isAdmin(Authentication auth) {
        return auth != null && auth.getAuthorities().stream().anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));
    }

    /** The restaurants this caller owns (empty for an owner with no owner record, or for anyone else). An admin is not limited by this. */
    public Set<Integer> restaurantIdsOf(Authentication auth) {
        Set<Integer> ids = new HashSet<>();
        if (auth == null || auth.getName() == null) return ids;
        for (RestaurantOwner o : owners.findByEmailIgnoreCase(auth.getName())) {
            for (Restaurant r : restaurants.findByOwner_OwnerId(o.getOwnerId())) ids.add(r.getId());
        }
        return ids;
    }

    /** The caller may manage this restaurant, or the request is refused with 403. */
    public void requireRestaurant(Authentication auth, Integer restaurantId) {
        if (isAdmin(auth)) return;
        if (restaurantId == null || !restaurantIdsOf(auth).contains(restaurantId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, DENIED);
        }
    }

    public void requireMenuItem(Authentication auth, int itemId) {
        if (isAdmin(auth)) return;
        MenuItem item = items.findById(itemId).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Menu item not found"));
        requireRestaurant(auth, restaurantOf(item.getCategory()));
    }

    public void requireCategory(Authentication auth, int categoryId) {
        if (isAdmin(auth)) return;
        MenuCategory c = categories.findById(categoryId).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Category not found"));
        requireRestaurant(auth, restaurantOf(c));
    }

    /** For a dish arriving in a request body: it has to be put into one of the caller's own menu sections. */
    public void requireCategoryOf(Authentication auth, MenuItem item) {
        if (isAdmin(auth)) return;
        if (item == null || item.getCategory() == null || item.getCategory().getId() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "A dish needs a menu section.");
        }
        requireCategory(auth, item.getCategory().getId());
    }

    public void requireDrop(Authentication auth, int dropId) {
        if (isAdmin(auth)) return;
        Drop d = drops.findById(dropId).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Drop not found"));
        requireRestaurant(auth, d.getRestaurantId());
    }

    /** The owner record a new restaurant created by this caller belongs to; an owner without one cannot create a restaurant. */
    public RestaurantOwner ownerRecordOf(Authentication auth) {
        List<RestaurantOwner> mine = owners.findByEmailIgnoreCase(auth.getName());
        if (mine.isEmpty()) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No restaurant owner profile exists for this account.");
        return mine.get(0);
    }

    /** True for the owner record that carries this caller's email (an owner reading their own profile). */
    public boolean isSelf(Authentication auth, int ownerId) {
        return owners.findById(ownerId).map(o -> o.getEmail() != null && o.getEmail().equalsIgnoreCase(auth.getName())).orElse(false);
    }

    private static Integer restaurantOf(MenuCategory c) {
        return c == null || c.getRestaurant() == null ? null : c.getRestaurant().getId();
    }
}
