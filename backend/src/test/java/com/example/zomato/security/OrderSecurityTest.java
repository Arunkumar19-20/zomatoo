package com.example.zomato.security;

import com.example.zomato.entity.*;
import com.example.zomato.repository.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
public class OrderSecurityTest {

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
    private RestaurantRepository restaurantRepository;

    @Autowired
    private MenuCategoryRepository categoryRepository;

    @Autowired
    private MenuItemRepository menuItemRepository;

    @Autowired
    private RestaurantOwnerRepository restaurantOwnerRepository;

    @Autowired
    private DeliveryRepository deliveryRepository;

    @Autowired
    private DeliveryPartnerRepository deliveryPartnerRepository;

    private User userA;
    private User userB;
    private Customer customerA;
    private Customer customerB;
    private Cart cartA;
    private Cart cartB;
    private Order orderB;
    private String tokenA;
    private String tokenB;
    private String tokenOwner;
    private String tokenOtherOwner;
    private String tokenAdmin;
    private String tokenDeliveryAssigned;
    private String tokenDeliveryUnassigned;
    private Restaurant restaurant;

    @BeforeEach
    void setUp() {
        deliveryRepository.deleteAll();
        deliveryPartnerRepository.deleteAll();
        orderRepository.deleteAll();
        cartItemRepository.deleteAll();
        cartRepository.deleteAll();
        customerRepository.deleteAll();
        userRepository.deleteAll();
        menuItemRepository.deleteAll();
        categoryRepository.deleteAll();
        restaurantRepository.deleteAll();
        restaurantOwnerRepository.deleteAll();

        // Setup Restaurant Owner Mario
        User ownerUser = new User("Owner Mario", "mario@bellaitalia.com", "OWNER");
        ownerUser.setEmailVerified(true);
        userRepository.save(ownerUser);

        RestaurantOwner ownerMario = new RestaurantOwner();
        ownerMario.setOwnerName("Owner Mario");
        ownerMario.setEmail("mario@bellaitalia.com");
        ownerMario = restaurantOwnerRepository.save(ownerMario);

        // Setup Other Owner Luigi (not owner of Bella Italia)
        User otherOwnerUser = new User("Owner Luigi", "luigi@otherresto.com", "OWNER");
        otherOwnerUser.setEmailVerified(true);
        userRepository.save(otherOwnerUser);

        // Setup Admin
        User adminUser = new User("System Admin", "admin@platform.com", "ADMIN");
        adminUser.setEmailVerified(true);
        userRepository.save(adminUser);

        // Setup Restaurant & Menu Item
        restaurant = new Restaurant();
        restaurant.setName("Bella Italia");
        restaurant.setOwner(ownerMario);
        restaurant = restaurantRepository.save(restaurant);

        MenuCategory category = new MenuCategory();
        category.setName("Main");
        category.setRestaurant(restaurant);
        category = categoryRepository.save(category);

        MenuItem item = new MenuItem();
        item.setName("Margherita Pizza");
        item.setPrice(12.99f);
        item.setCategory(category);
        item = menuItemRepository.save(item);

        // Setup User A
        userA = new User("Alice", "alice@test.com", "CUSTOMER");
        userA.setEmailVerified(true);
        userA = userRepository.save(userA);

        customerA = new Customer();
        customerA.setName("Alice");
        customerA.setEmail("alice@test.com");
        customerA = customerRepository.save(customerA);

        cartA = new Cart();
        cartA.setCustomer(customerA);
        cartA.setRestaurant(restaurant);
        cartA = cartRepository.save(cartA);

        CartItem itemA = new CartItem();
        itemA.setCart(cartA);
        itemA.setItem(item);
        itemA.setPrice(12.99);
        itemA.setQuantity(1);
        cartItemRepository.save(itemA);

        // Setup User B
        userB = new User("Bob", "bob@test.com", "CUSTOMER");
        userB.setEmailVerified(true);
        userB = userRepository.save(userB);

        customerB = new Customer();
        customerB.setName("Bob");
        customerB.setEmail("bob@test.com");
        customerB = customerRepository.save(customerB);

        cartB = new Cart();
        cartB.setCustomer(customerB);
        cartB.setRestaurant(restaurant);
        cartB = cartRepository.save(cartB);

        CartItem itemB = new CartItem();
        itemB.setCart(cartB);
        itemB.setItem(item);
        itemB.setPrice(12.99);
        itemB.setQuantity(2);
        cartItemRepository.save(itemB);

        // Create an existing Order for User B
        orderB = new Order();
        orderB.setCustomer(customerB);
        orderB.setRestaurant(restaurant);
        orderB.setTotalAmount(25.98f);
        orderB.setStatus("PLACED");
        orderB.setOrderDate(LocalDateTime.now());
        orderB = orderRepository.save(orderB);

        tokenA = "Bearer " + jwtService.generateToken(userA.getEmail(), "CUSTOMER");
        tokenB = "Bearer " + jwtService.generateToken(userB.getEmail(), "CUSTOMER");
        tokenOwner = "Bearer " + jwtService.generateToken("mario@bellaitalia.com", "OWNER");
        tokenOtherOwner = "Bearer " + jwtService.generateToken("luigi@otherresto.com", "OWNER");
        tokenAdmin = "Bearer " + jwtService.generateToken("admin@platform.com", "ADMIN");

        // Setup Delivery Partner Dan (assigned to orderB)
        User partnerUserDan = new User("Dan Delivery", "dan@speedy.com", "DELIVERY_PARTNER");
        partnerUserDan.setEmailVerified(true);
        userRepository.save(partnerUserDan);

        DeliveryPartner partnerDan = new DeliveryPartner();
        partnerDan.setEmail("dan@speedy.com");
        partnerDan.setVehicleType("BIKE");
        partnerDan.setVehicleNumber("KA-01-AB-1234");
        partnerDan = deliveryPartnerRepository.save(partnerDan);

        // Setup Delivery Partner Doug (unassigned)
        User partnerUserDoug = new User("Doug Delivery", "doug@speedy.com", "DELIVERY_PARTNER");
        partnerUserDoug.setEmailVerified(true);
        userRepository.save(partnerUserDoug);

        DeliveryPartner partnerDoug = new DeliveryPartner();
        partnerDoug.setEmail("doug@speedy.com");
        partnerDoug.setVehicleType("SCOOTER");
        partnerDoug.setVehicleNumber("KA-01-CD-5678");
        partnerDoug = deliveryPartnerRepository.save(partnerDoug);

        // Assign Dan to orderB
        Delivery delivery = new Delivery();
        delivery.setOrder(orderB);
        delivery.setDeliveryPartner(partnerDan);
        delivery.setStatus("ASSIGNED");
        deliveryRepository.save(delivery);

        tokenDeliveryAssigned = "Bearer " + jwtService.generateToken("dan@speedy.com", "DELIVERY_PARTNER");
        tokenDeliveryUnassigned = "Bearer " + jwtService.generateToken("doug@speedy.com", "DELIVERY_PARTNER");
    }

    @Test
    void userACannotFetchUserBOrder() throws Exception {
        // User A attempts to access User B's order by ID
        mockMvc.perform(get("/orders/" + orderB.getOrderId())
                        .header("Authorization", tokenA))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.message").value("Access denied to this order"));
    }

    @Test
    void userBCanFetchOwnOrder() throws Exception {
        // User B accesses their own order
        mockMvc.perform(get("/orders/" + orderB.getOrderId())
                        .header("Authorization", tokenB))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.orderId").value(orderB.getOrderId()));
    }

    @Test
    void userACannotCancelUserBOrder() throws Exception {
        // User A attempts to cancel User B's order
        mockMvc.perform(delete("/orders/" + orderB.getOrderId())
                        .header("Authorization", tokenA))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.message").value("You cannot cancel this order"));
    }

    @Test
    void userACannotPayForUserBOrder() throws Exception {
        // User A attempts to create payment intent for User B's order
        mockMvc.perform(post("/payment/create")
                        .header("Authorization", tokenA)
                        .param("orderId", String.valueOf(orderB.getOrderId())))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.message").value("Access denied to this order"));
    }

    @Test
    void userACheckoutIgnoresSpoofedCustomerIdAndCartId() throws Exception {
        // User A attempts IDOR by supplying User B's customerId and cartId in the request
        mockMvc.perform(post("/orders/checkout")
                        .header("Authorization", tokenA)
                        .param("customerId", String.valueOf(customerB.getCustomerId()))
                        .param("cartId", String.valueOf(cartB.getId()))
                        .param("restaurantId", String.valueOf(restaurant.getId())))
                .andExpect(status().isOk());

        // Confirm User A's cart items were cleared upon checkout
        assertTrue(cartItemRepository.findByCartId(cartA.getId()).isEmpty());

        // CRITICAL: Confirm User B's cart was NOT touched by User A's checkout!
        assertEquals(1, cartItemRepository.findByCartId(cartB.getId()).size());

        // Confirm orders in repository: User A has 1 order, User B still has 1 order (the original one)
        assertEquals(1, orderRepository.findByCustomer_Email(userA.getEmail()).size());
        assertEquals(1, orderRepository.findByCustomer_Email(userB.getEmail()).size());
    }

    @Test
    void customerCannotMarkOrderAsDelivered() throws Exception {
        // Customer attempts to update order status to DELIVERED
        mockMvc.perform(put("/orders/" + orderB.getOrderId() + "/status")
                        .header("Authorization", tokenA)
                        .param("status", "DELIVERED"))
                .andExpect(status().isForbidden());
    }

    @Test
    void unauthorizedOwnerCannotUpdateOtherRestaurantOrderStatus() throws Exception {
        // Luigi owns another restaurant, not Bella Italia (which owns orderB)
        mockMvc.perform(put("/orders/" + orderB.getOrderId() + "/status")
                        .header("Authorization", tokenOtherOwner)
                        .param("status", "PREPARING"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.message").value("Access denied: you do not own the restaurant for this order"));
    }

    @Test
    void ownerCannotConfirmUnpaidOrder() throws Exception {
        // Mario attempts to confirm an order whose paymentStatus is PENDING -> rejected
        mockMvc.perform(put("/orders/" + orderB.getOrderId() + "/status")
                        .header("Authorization", tokenOwner)
                        .param("status", "CONFIRMED"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Cannot confirm order until payment is PAID"));
    }

    @Test
    void legitimateOwnerCanUpdateOrderStatusAlongStateMachine() throws Exception {
        // Mario is the genuine owner of Bella Italia. Once order is PAID, he can confirm and prepare it.
        orderB.setPaymentStatus(PaymentStatus.PAID);
        orderRepository.save(orderB);

        // Step 1: PLACED -> CONFIRMED
        mockMvc.perform(put("/orders/" + orderB.getOrderId() + "/status")
                        .header("Authorization", tokenOwner)
                        .param("status", "CONFIRMED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.orderId").value(orderB.getOrderId()))
                .andExpect(jsonPath("$.status").value("CONFIRMED"));

        // Step 2: CONFIRMED -> PREPARING
        mockMvc.perform(put("/orders/" + orderB.getOrderId() + "/status")
                        .header("Authorization", tokenOwner)
                        .param("status", "PREPARING"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.orderId").value(orderB.getOrderId()))
                .andExpect(jsonPath("$.status").value("PREPARING"));
    }

    @Test
    void ownerCannotMarkOrderAsDelivered() throws Exception {
        // Mario attempts to jump or mark order as DELIVERED -> forbidden for owners
        mockMvc.perform(put("/orders/" + orderB.getOrderId() + "/status")
                        .header("Authorization", tokenOwner)
                        .param("status", "DELIVERED"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.message").value("Access denied: restaurant owners cannot mark orders as DELIVERED"));
    }

    @Test
    void illegalStatusTransitionReturnsBadRequest() throws Exception {
        // Admin attempts invalid jump: PLACED directly to DELIVERED
        mockMvc.perform(put("/orders/" + orderB.getOrderId() + "/status")
                        .header("Authorization", tokenAdmin)
                        .param("status", "DELIVERED"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Invalid order status transition from PLACED to DELIVERED"));
    }

    @Test
    void cannotCancelOrderOncePreparing() throws Exception {
        // Move order to PREPARING (must be PAID first)
        orderB.setPaymentStatus(PaymentStatus.PAID);
        orderRepository.save(orderB);

        mockMvc.perform(put("/orders/" + orderB.getOrderId() + "/status")
                        .header("Authorization", tokenOwner)
                        .param("status", "CONFIRMED"))
                .andExpect(status().isOk());

        mockMvc.perform(put("/orders/" + orderB.getOrderId() + "/status")
                        .header("Authorization", tokenOwner)
                        .param("status", "PREPARING"))
                .andExpect(status().isOk());

        // Customer Bob tries to cancel order while PREPARING -> rejected with 400 Bad Request
        mockMvc.perform(delete("/orders/" + orderB.getOrderId())
                        .header("Authorization", tokenB))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Cannot cancel order in status: PREPARING"));
    }

    @Test
    void unassignedDeliveryPartnerCannotUpdateStatus() throws Exception {
        // Advance order to PREPARING (must be PAID first)
        orderB.setPaymentStatus(PaymentStatus.PAID);
        orderRepository.save(orderB);

        mockMvc.perform(put("/orders/" + orderB.getOrderId() + "/status")
                        .header("Authorization", tokenOwner)
                        .param("status", "CONFIRMED"))
                .andExpect(status().isOk());

        mockMvc.perform(put("/orders/" + orderB.getOrderId() + "/status")
                        .header("Authorization", tokenOwner)
                        .param("status", "PREPARING"))
                .andExpect(status().isOk());

        // Doug (unassigned partner) tries to mark OUT_FOR_DELIVERY
        mockMvc.perform(put("/orders/" + orderB.getOrderId() + "/status")
                        .header("Authorization", tokenDeliveryUnassigned)
                        .param("status", "OUT_FOR_DELIVERY"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.message").value("Access denied: you are not the assigned delivery partner for this order"));
    }

    @Test
    void assignedDeliveryPartnerCanUpdateStatus() throws Exception {
        // Advance order to PREPARING (must be PAID first)
        orderB.setPaymentStatus(PaymentStatus.PAID);
        orderRepository.save(orderB);

        mockMvc.perform(put("/orders/" + orderB.getOrderId() + "/status")
                        .header("Authorization", tokenOwner)
                        .param("status", "CONFIRMED"))
                .andExpect(status().isOk());

        mockMvc.perform(put("/orders/" + orderB.getOrderId() + "/status")
                        .header("Authorization", tokenOwner)
                        .param("status", "PREPARING"))
                .andExpect(status().isOk());

        // Dan (assigned partner) transitions PREPARING -> OUT_FOR_DELIVERY
        mockMvc.perform(put("/orders/" + orderB.getOrderId() + "/status")
                        .header("Authorization", tokenDeliveryAssigned)
                        .param("status", "OUT_FOR_DELIVERY"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("OUT_FOR_DELIVERY"));

        // Dan transitions OUT_FOR_DELIVERY -> DELIVERED
        mockMvc.perform(put("/orders/" + orderB.getOrderId() + "/status")
                        .header("Authorization", tokenDeliveryAssigned)
                        .param("status", "DELIVERED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("DELIVERED"));
    }

    @Test
    void adminCanUpdateOrderStatus() throws Exception {
        // System admin can update valid transition: PLACED -> CONFIRMED
        mockMvc.perform(put("/orders/" + orderB.getOrderId() + "/status")
                        .header("Authorization", tokenAdmin)
                        .param("status", "CONFIRMED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.orderId").value(orderB.getOrderId()))
                .andExpect(jsonPath("$.status").value("CONFIRMED"));
    }
}
