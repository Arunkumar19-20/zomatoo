package com.example.zomato.order;

import com.example.zomato.entity.*;
import com.example.zomato.repository.*;
import com.example.zomato.security.JwtService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
public class OrderDtoLeakTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CustomerRepository customerRepository;

    @Autowired
    private CartRepository cartRepository;

    @Autowired
    private CartItemRepository cartItemRepository;

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private OrderItemRepository orderItemRepository;

    @Autowired
    private RestaurantRepository restaurantRepository;

    @Autowired
    private MenuCategoryRepository categoryRepository;

    @Autowired
    private MenuItemRepository menuItemRepository;

    private User user;
    private Customer customer;
    private Restaurant restaurant;
    private MenuItem menuItem;
    private String jwtToken;

    @BeforeEach
    void setUp() {
        orderItemRepository.deleteAll();
        orderRepository.deleteAll();
        cartItemRepository.deleteAll();
        cartRepository.deleteAll();
        customerRepository.deleteAll();
        userRepository.deleteAll();
        menuItemRepository.deleteAll();
        categoryRepository.deleteAll();
        restaurantRepository.deleteAll();

        // Setup Restaurant & Item
        restaurant = new Restaurant();
        restaurant.setName("Trattoria Deliziosa");
        restaurant.setAddress("123 Rome Blvd");
        restaurant.setImageUrl("https://img.com/trattoria.png");
        restaurant = restaurantRepository.save(restaurant);

        MenuCategory cat = new MenuCategory();
        cat.setName("Pasta");
        cat.setRestaurant(restaurant);
        cat = categoryRepository.save(cat);

        menuItem = new MenuItem();
        menuItem.setName("Pasta Carbonara");
        menuItem.setPrice(14.50f);
        menuItem.setImageUrl("https://img.com/carbonara.png");
        menuItem.setCategory(cat);
        menuItem = menuItemRepository.save(menuItem);

        // Setup User with sensitive properties
        user = new User();
        user.setName("Sensitive Customer");
        user.setEmail("sensitive@domain.com");
        user.setPassword("$2a$12$SuperSecretHashedPasswordVal12345678901234567890");
        user.setRole("CUSTOMER");
        user.setEmailVerified(true);
        user.setEmailVerificationToken("VERIF-TOKEN-999-SECRET");
        user.setPasswordResetToken("RESET-TOKEN-111-SECRET");
        user = userRepository.save(user);

        customer = new Customer();
        customer.setName(user.getName());
        customer.setEmail(user.getEmail());
        customer.setUserId(user.getUserId());
        customer = customerRepository.save(customer);

        Cart cart = new Cart();
        cart.setCustomer(customer);
        cart.setRestaurant(restaurant);
        cart = cartRepository.save(cart);

        CartItem cartItem = new CartItem();
        cartItem.setCart(cart);
        cartItem.setItem(menuItem);
        cartItem.setPrice(14.50);
        cartItem.setQuantity(2);
        cartItemRepository.save(cartItem);

        jwtToken = "Bearer " + jwtService.generateToken(user.getEmail(), "CUSTOMER");
    }

    private void assertNoSensitiveEntityOrUserLeaks(String jsonBody) {
        assertFalse(jsonBody.contains("password"), "Response must not leak password: " + jsonBody);
        assertFalse(jsonBody.contains("SuperSecretHashedPasswordVal"), "Response must not leak password hash: " + jsonBody);
        assertFalse(jsonBody.contains("emailVerificationToken"), "Response must not leak email verification token: " + jsonBody);
        assertFalse(jsonBody.contains("passwordResetToken"), "Response must not leak password reset token: " + jsonBody);
        assertFalse(jsonBody.contains("VERIF-TOKEN"), "Response must not leak raw verification token: " + jsonBody);
        assertFalse(jsonBody.contains("RESET-TOKEN"), "Response must not leak raw reset token: " + jsonBody);
        assertFalse(jsonBody.contains("\"userId\""), "Response must not leak internal user entity ID: " + jsonBody);
        assertFalse(jsonBody.contains("\"customerId\""), "Response must not leak internal customer entity ID: " + jsonBody);
        assertFalse(jsonBody.contains("\"user\""), "Response must not leak nested user entity: " + jsonBody);
        assertFalse(jsonBody.contains("\"role\""), "Response must not leak user role: " + jsonBody);
        assertFalse(jsonBody.contains("\"owner\""), "Response must not leak restaurant owner entity: " + jsonBody);
        assertFalse(jsonBody.contains("\"ownerId\""), "Response must not leak owner entity ID: " + jsonBody);
    }

    @Test
    void checkout_returnsOrderResponseDto_withoutEntityOrUserLeaks() throws Exception {
        MvcResult result = mockMvc.perform(post("/orders/checkout")
                        .header("Authorization", jwtToken)
                        .param("restaurantId", String.valueOf(restaurant.getId())))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.orderId", greaterThan(0)))
                .andExpect(jsonPath("$.status").value("PLACED"))
                .andExpect(jsonPath("$.paymentStatus").value("PENDING"))
                .andExpect(jsonPath("$.totalAmount").value(29.0))
                .andExpect(jsonPath("$.restaurantName").value("Trattoria Deliziosa"))
                .andExpect(jsonPath("$.customerName").value("Sensitive Customer"))
                .andExpect(jsonPath("$.customerEmail").value("sensitive@domain.com"))
                .andExpect(jsonPath("$.items", hasSize(1)))
                .andExpect(jsonPath("$.items[0].name").value("Pasta Carbonara"))
                .andExpect(jsonPath("$.items[0].quantity").value(2))
                .andExpect(jsonPath("$.items[0].price").value(14.50))
                .andReturn();

        assertNoSensitiveEntityOrUserLeaks(result.getResponse().getContentAsString());
    }

    @Test
    void getOrderById_returnsOrderResponseDto_withoutEntityOrUserLeaks() throws Exception {
        // Place order first
        MvcResult checkoutRes = mockMvc.perform(post("/orders/checkout")
                        .header("Authorization", jwtToken)
                        .param("restaurantId", String.valueOf(restaurant.getId())))
                .andExpect(status().isOk())
                .andReturn();

        Integer orderId = com.jayway.jsonpath.JsonPath.read(checkoutRes.getResponse().getContentAsString(), "$.orderId");

        // Fetch via GET /orders/{id}
        MvcResult getRes = mockMvc.perform(get("/orders/" + orderId)
                        .header("Authorization", jwtToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.orderId").value(orderId))
                .andExpect(jsonPath("$.status").value("PLACED"))
                .andExpect(jsonPath("$.restaurantName").value("Trattoria Deliziosa"))
                .andExpect(jsonPath("$.items", hasSize(1)))
                .andReturn();

        assertNoSensitiveEntityOrUserLeaks(getRes.getResponse().getContentAsString());
    }

    @Test
    void getOrders_returnsUserHistory_withoutEntityOrUserLeaks() throws Exception {
        // Place order first
        mockMvc.perform(post("/orders/checkout")
                        .header("Authorization", jwtToken)
                        .param("restaurantId", String.valueOf(restaurant.getId())))
                .andExpect(status().isOk());

        // Call new GET /orders endpoint
        MvcResult listRes = mockMvc.perform(get("/orders")
                        .header("Authorization", jwtToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)))
                .andExpect(jsonPath("$[0].restaurantName").value("Trattoria Deliziosa"))
                .andExpect(jsonPath("$[0].customerEmail").value("sensitive@domain.com"))
                .andReturn();

        assertNoSensitiveEntityOrUserLeaks(listRes.getResponse().getContentAsString());

        // Also verify GET /orders/my-orders returns the same clean DTO list
        MvcResult myOrdersRes = mockMvc.perform(get("/orders/my-orders")
                        .header("Authorization", jwtToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)))
                .andReturn();

        assertNoSensitiveEntityOrUserLeaks(myOrdersRes.getResponse().getContentAsString());
    }
}
