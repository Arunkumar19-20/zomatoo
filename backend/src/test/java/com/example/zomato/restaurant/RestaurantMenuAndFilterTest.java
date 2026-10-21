package com.example.zomato.restaurant;

import com.example.zomato.entity.Location;
import com.example.zomato.entity.MenuCategory;
import com.example.zomato.entity.MenuItem;
import com.example.zomato.entity.Restaurant;
import com.example.zomato.repository.LocationRepository;
import com.example.zomato.repository.MenuCategoryRepository;
import com.example.zomato.repository.MenuItemRepository;
import com.example.zomato.repository.RestaurantRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
public class RestaurantMenuAndFilterTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private RestaurantRepository restaurantRepository;

    @Autowired
    private MenuCategoryRepository categoryRepository;

    @Autowired
    private MenuItemRepository menuItemRepository;

    @Autowired
    private LocationRepository locationRepository;

    @Autowired
    private com.example.zomato.repository.OrderItemRepository orderItemRepository;

    @Autowired
    private com.example.zomato.repository.OrderRepository orderRepository;

    @Autowired
    private com.example.zomato.repository.CartItemRepository cartItemRepository;

    @Autowired
    private com.example.zomato.repository.CartRepository cartRepository;

    private Restaurant rItalian;
    private Restaurant rIndian;
    private Restaurant rMexicanClosed;

    @BeforeEach
    void setUp() {
        orderItemRepository.deleteAll();
        orderRepository.deleteAll();
        cartItemRepository.deleteAll();
        cartRepository.deleteAll();
        menuItemRepository.deleteAll();
        categoryRepository.deleteAll();
        restaurantRepository.deleteAll();
        locationRepository.deleteAll();

        Location loc1 = new Location();
        loc1.setCity("New York");
        loc1 = locationRepository.save(loc1);

        Location loc2 = new Location();
        loc2.setCity("Chicago");
        loc2 = locationRepository.save(loc2);

        // Restaurant 1: Italian, open, rating 4.8
        rItalian = new Restaurant();
        rItalian.setName("Luigi's Trattoria");
        rItalian.setCuisine("Italian");
        rItalian.setRating(4.8f);
        rItalian.setOpen(true);
        rItalian.setLocation(loc1);
        rItalian = restaurantRepository.save(rItalian);

        // Restaurant 2: Indian, open, rating 4.2
        rIndian = new Restaurant();
        rIndian.setName("Spice Symphony");
        rIndian.setCuisine("Indian Curry");
        rIndian.setRating(4.2f);
        rIndian.setOpen(true);
        rIndian.setLocation(loc1);
        rIndian = restaurantRepository.save(rIndian);

        // Restaurant 3: Mexican, closed, rating 4.5
        rMexicanClosed = new Restaurant();
        rMexicanClosed.setName("El Sombrero");
        rMexicanClosed.setCuisine("Mexican Tacos");
        rMexicanClosed.setRating(4.5f);
        rMexicanClosed.setOpen(false);
        rMexicanClosed.setLocation(loc2);
        rMexicanClosed = restaurantRepository.save(rMexicanClosed);

        // Categories & Items for rItalian
        MenuCategory catStarters = new MenuCategory();
        catStarters.setName("Starters");
        catStarters.setDisplayOrder(1);
        catStarters.setRestaurant(rItalian);
        catStarters = categoryRepository.save(catStarters);

        MenuCategory catMains = new MenuCategory();
        catMains.setName("Mains");
        catMains.setDisplayOrder(2);
        catMains.setRestaurant(rItalian);
        catMains = categoryRepository.save(catMains);

        MenuCategory catEmpty = new MenuCategory();
        catEmpty.setName("Seasonal Specials");
        catEmpty.setDisplayOrder(3);
        catEmpty.setRestaurant(rItalian);
        catEmpty = categoryRepository.save(catEmpty);

        // Item 1: available starter
        MenuItem item1 = new MenuItem();
        item1.setName("Bruschetta");
        item1.setPrice(7.50f);
        item1.setIsVeg(true);
        item1.setIsAvailable(true);
        item1.setCategory(catStarters);
        menuItemRepository.save(item1);

        // Item 2: available main
        MenuItem item2 = new MenuItem();
        item2.setName("Lasagna");
        item2.setPrice(15.00f);
        item2.setIsVeg(false);
        item2.setIsAvailable(true);
        item2.setCategory(catMains);
        menuItemRepository.save(item2);

        // Item 3: UNAVAILABLE item (isAvailable = false)
        MenuItem item3 = new MenuItem();
        item3.setName("Truffle Risotto");
        item3.setPrice(22.00f);
        item3.setIsVeg(true);
        item3.setIsAvailable(false);
        item3.setCategory(catMains);
        menuItemRepository.save(item3);
    }

    @Test
    void getMenu_unknownRestaurantReturns404() throws Exception {
        mockMvc.perform(get("/restaurants/99999/menu"))
                .andExpect(status().isNotFound());
    }

    @Test
    void getMenu_nestedCategoriesAndItems_emptyCategoryAndUnavailableItemPreserved() throws Exception {
        mockMvc.perform(get("/restaurants/" + rItalian.getId() + "/menu")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(3)))
                // Category 1: Starters
                .andExpect(jsonPath("$[0].name").value("Starters"))
                .andExpect(jsonPath("$[0].items", hasSize(1)))
                .andExpect(jsonPath("$[0].items[0].name").value("Bruschetta"))
                .andExpect(jsonPath("$[0].items[0].isAvailable").value(true))
                // Category 2: Mains with available and unavailable items
                .andExpect(jsonPath("$[1].name").value("Mains"))
                .andExpect(jsonPath("$[1].items", hasSize(2)))
                .andExpect(jsonPath("$[1].items[0].name").value("Lasagna"))
                .andExpect(jsonPath("$[1].items[0].isAvailable").value(true))
                .andExpect(jsonPath("$[1].items[1].name").value("Truffle Risotto"))
                .andExpect(jsonPath("$[1].items[1].isAvailable").value(false))
                // Category 3: Empty category returns empty items list
                .andExpect(jsonPath("$[2].name").value("Seasonal Specials"))
                .andExpect(jsonPath("$[2].items", empty()));
    }

    @Test
    void getRestaurants_filterByCuisine() throws Exception {
        mockMvc.perform(get("/restaurants")
                        .param("cuisine", "italian"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(1)))
                .andExpect(jsonPath("$.content[0].name").value("Luigi's Trattoria"));
    }

    @Test
    void getRestaurants_filterByMinRating() throws Exception {
        // minRating 4.5 -> Luigi's (4.8) and El Sombrero (4.5)
        mockMvc.perform(get("/restaurants")
                        .param("minRating", "4.5"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(2)))
                .andExpect(jsonPath("$.content[*].name", containsInAnyOrder("Luigi's Trattoria", "El Sombrero")));
    }

    @Test
    void getRestaurants_filterByIsOpen() throws Exception {
        // isOpen = false -> only El Sombrero
        mockMvc.perform(get("/restaurants")
                        .param("isOpen", "false"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(1)))
                .andExpect(jsonPath("$.content[0].name").value("El Sombrero"));
    }

    @Test
    void getRestaurants_filterBySearch() throws Exception {
        // search "curry" matches Spice Symphony's cuisine
        mockMvc.perform(get("/restaurants")
                        .param("search", "curry"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(1)))
                .andExpect(jsonPath("$.content[0].name").value("Spice Symphony"));

        // search "luigi" matches Luigi's Trattoria name
        mockMvc.perform(get("/restaurants")
                        .param("search", "Luigi"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(1)))
                .andExpect(jsonPath("$.content[0].name").value("Luigi's Trattoria"));
    }

    @Test
    void getRestaurants_paginationAndSorting() throws Exception {
        // sort by rating desc, page size 2
        mockMvc.perform(get("/restaurants")
                        .param("page", "0")
                        .param("size", "2")
                        .param("sort", "rating,desc"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(2)))
                .andExpect(jsonPath("$.content[0].name").value("Luigi's Trattoria")) // 4.8
                .andExpect(jsonPath("$.content[1].name").value("El Sombrero"))      // 4.5
                .andExpect(jsonPath("$.totalElements").value(3))
                .andExpect(jsonPath("$.totalPages").value(2));
    }

    @Test
    void getRestaurantById_returnsDtoAnd404OnMissing() throws Exception {
        mockMvc.perform(get("/restaurants/" + rItalian.getId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(rItalian.getId()))
                .andExpect(jsonPath("$.name").value("Luigi's Trattoria"))
                .andExpect(jsonPath("$.locationCity").value("New York"));

        mockMvc.perform(get("/restaurants/99999"))
                .andExpect(status().isNotFound());
    }
}
