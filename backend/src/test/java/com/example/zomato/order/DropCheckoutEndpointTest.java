package com.example.zomato.order;

import com.example.zomato.dto.ReservationResponseDTO;
import com.example.zomato.entity.*;
import com.example.zomato.repository.*;
import com.example.zomato.security.JwtService;
import com.example.zomato.services.CartService;
import com.example.zomato.services.CustomerService;
import com.example.zomato.services.DropService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.LocalDateTime;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
public class DropCheckoutEndpointTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private DropService dropService;

    @Autowired
    private DropRepository dropRepository;

    @Autowired
    private DropReservationRepository reservationRepository;

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CustomerRepository customerRepository;

    @Autowired
    private CustomerService customerService;

    @Autowired
    private RestaurantRepository restaurantRepository;

    @Autowired
    private MenuItemRepository menuItemRepository;

    @Autowired
    private MenuCategoryRepository menuCategoryRepository;

    @Autowired
    private CartRepository cartRepository;

    @Autowired
    private CartItemRepository cartItemRepository;

    @Autowired
    private CartService cartService;

    @Autowired
    private PlatformTransactionManager transactionManager;

    private TransactionTemplate transactionTemplate;
    private User alice;
    private User bob;
    private Restaurant restaurant;
    private Drop drop;
    private MenuItem menuItem;

    @BeforeEach
    void setUp() {
        transactionTemplate = new TransactionTemplate(transactionManager);

        transactionTemplate.execute(status -> {
            cartItemRepository.deleteAll();
            cartRepository.deleteAll();
            reservationRepository.deleteAll();
            orderRepository.deleteAll();

            alice = userRepository.findByEmail("alice@test.com").orElseGet(() -> {
                User u = new User("Alice", "alice@test.com", "CUSTOMER");
                u.setPassword("Password123!");
                u.setEmailVerified(true);
                return userRepository.save(u);
            });
            customerService.getOrCreateCustomer("alice@test.com", "Alice");

            bob = userRepository.findByEmail("bob@test.com").orElseGet(() -> {
                User u = new User("Bob", "bob@test.com", "CUSTOMER");
                u.setPassword("Password123!");
                u.setEmailVerified(true);
                return userRepository.save(u);
            });
            customerService.getOrCreateCustomer("bob@test.com", "Bob");

            restaurant = restaurantRepository.findAll().stream().findFirst().orElseGet(() -> {
                Restaurant r = new Restaurant();
                r.setName("Drop Checkout Test Kitchen");
                return restaurantRepository.save(r);
            });

            MenuCategory category = menuCategoryRepository.findAll().stream().findFirst().orElseGet(() -> {
                MenuCategory mc = new MenuCategory();
                mc.setName("Standard Mains");
                mc.setRestaurant(restaurant);
                return menuCategoryRepository.save(mc);
            });

            menuItem = menuItemRepository.findAll().stream().findFirst().orElseGet(() -> {
                MenuItem mi = new MenuItem();
                mi.setName("Standard Burger");
                mi.setPrice(12.5f);
                mi.setCategory(category);
                return menuItemRepository.save(mi);
            });

            Drop d = new Drop();
            d.setTitle("Exclusive Truffle Burger Drop");
            d.setDescription("Server-priced drop dish");
            d.setPrice(45.0);
            d.setTotalSlots(3);
            d.setReservedSlots(0);
            d.setRestaurantId(restaurant.getId());
            d.setMenuItemId(menuItem.getId());
            d.setStartsAt(LocalDateTime.now().minusMinutes(5));
            d.setEndsAt(LocalDateTime.now().plusHours(2));
            drop = dropRepository.save(d);

            return null;
        });
    }

    @Test
    void testCheckoutDropWithReservationIdQueryParamSuccess() throws Exception {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@test.com");
        String aliceToken = "Bearer " + jwtService.generateToken("alice@test.com", "CUSTOMER");

        mockMvc.perform(post("/orders/checkout")
                        .header("Authorization", aliceToken)
                        .param("reservationId", String.valueOf(res.reservationId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PLACED"))
                .andExpect(jsonPath("$.paymentStatus").value("PENDING"))
                .andExpect(jsonPath("$.totalAmount").value(45.0))
                .andExpect(jsonPath("$.items", hasSize(1)))
                .andExpect(jsonPath("$.items[0].name").value("Exclusive Truffle Burger Drop"))
                .andExpect(jsonPath("$.items[0].price").value(45.0));

        // Verify reservation links to order
        DropReservation savedRes = reservationRepository.findById(res.reservationId()).orElseThrow();
        assertEquals(ReservationStatus.HELD, savedRes.getStatus());
        assertEquals("alice@test.com", savedRes.getCustomerEmail());
    }

    @Test
    void testCheckoutDropWithReservationIdInRequestBodySuccess() throws Exception {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@test.com");
        String aliceToken = "Bearer " + jwtService.generateToken("alice@test.com", "CUSTOMER");

        String body = String.format("{\"reservationId\": %d}", res.reservationId());

        mockMvc.perform(post("/orders/checkout")
                        .header("Authorization", aliceToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalAmount").value(45.0))
                .andExpect(jsonPath("$.items", hasSize(1)))
                .andExpect(jsonPath("$.items[0].name").value("Exclusive Truffle Burger Drop"));
    }

    @Test
    void testCheckoutDropReservationNotFoundReturns404() throws Exception {
        String aliceToken = "Bearer " + jwtService.generateToken("alice@test.com", "CUSTOMER");

        mockMvc.perform(post("/orders/checkout")
                        .header("Authorization", aliceToken)
                        .param("reservationId", "999999"))
                .andExpect(status().isNotFound());
    }

    @Test
    void testCheckoutDropReservationNotYoursReturns403() throws Exception {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@test.com");
        String bobToken = "Bearer " + jwtService.generateToken("bob@test.com", "CUSTOMER");

        // Bob tries to checkout Alice's reservation
        mockMvc.perform(post("/orders/checkout")
                        .header("Authorization", bobToken)
                        .param("reservationId", String.valueOf(res.reservationId())))
                .andExpect(status().isForbidden());
    }

    @Test
    void testCheckoutDropReservationExpiredReturns409() throws Exception {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@test.com");
        String aliceToken = "Bearer " + jwtService.generateToken("alice@test.com", "CUSTOMER");

        // Force expiry in the past
        transactionTemplate.execute(status -> {
            DropReservation r = reservationRepository.findById(res.reservationId()).orElseThrow();
            r.setExpiresAt(LocalDateTime.now().minusMinutes(5));
            reservationRepository.saveAndFlush(r);
            return null;
        });

        mockMvc.perform(post("/orders/checkout")
                        .header("Authorization", aliceToken)
                        .param("reservationId", String.valueOf(res.reservationId())))
                .andExpect(status().isConflict());
    }

    @Test
    void testCheckoutDropReservationAlreadyUsedReturns409() throws Exception {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@test.com");
        String aliceToken = "Bearer " + jwtService.generateToken("alice@test.com", "CUSTOMER");

        // First checkout succeeds
        mockMvc.perform(post("/orders/checkout")
                        .header("Authorization", aliceToken)
                        .param("reservationId", String.valueOf(res.reservationId())))
                .andExpect(status().isOk());

        // Second checkout attempt on same reservation fails with 409
        mockMvc.perform(post("/orders/checkout")
                        .header("Authorization", aliceToken)
                        .param("reservationId", String.valueOf(res.reservationId())))
                .andExpect(status().isConflict());
    }

    @Test
    void testNormalCartCheckoutRegression() throws Exception {
        String aliceToken = "Bearer " + jwtService.generateToken("alice@test.com", "CUSTOMER");

        // Alice adds regular menu item to cart
        cartService.addItemToCart("alice@test.com", new com.example.zomato.dto.AddToCartRequest(menuItem.getId(), 2));

        double expectedTotal = Math.round(menuItem.getPrice().doubleValue() * 2 * 100.0) / 100.0;
        // Normal cart checkout without reservationId
        mockMvc.perform(post("/orders/checkout")
                        .header("Authorization", aliceToken)
                        .param("restaurantId", String.valueOf(restaurant.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PLACED"))
                .andExpect(jsonPath("$.totalAmount").value(expectedTotal))
                .andExpect(jsonPath("$.items", hasSize(1)))
                .andExpect(jsonPath("$.items[0].name").value(menuItem.getName()))
                .andExpect(jsonPath("$.items[0].quantity").value(2));

        // Verify cart is emptied
        Customer cust = customerRepository.findByEmail("alice@test.com").orElseThrow();
        Cart cart = cartRepository.findByCustomer_CustomerId(cust.getCustomerId()).orElseThrow();
        assertEquals(0, cartItemRepository.findByCartId(cart.getId()).size());
    }

    @Test
    void testServerSidePricingImmunityIgnoresClientTampering() throws Exception {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@test.com");
        String aliceToken = "Bearer " + jwtService.generateToken("alice@test.com", "CUSTOMER");

        // Client attempts to send fraudulent price and title in the JSON body
        String tamperedBody = String.format("""
            {
              "reservationId": %d,
              "price": 1.00,
              "totalAmount": 1.00,
              "title": "Cheap Hacker Burger"
            }
            """, res.reservationId());

        mockMvc.perform(post("/orders/checkout")
                        .header("Authorization", aliceToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(tamperedBody))
                .andExpect(status().isOk())
                // Assert server price ($45.00) and title are strictly enforced
                .andExpect(jsonPath("$.totalAmount").value(45.0))
                .andExpect(jsonPath("$.items[0].name").value("Exclusive Truffle Burger Drop"))
                .andExpect(jsonPath("$.items[0].price").value(45.0));
    }
}
