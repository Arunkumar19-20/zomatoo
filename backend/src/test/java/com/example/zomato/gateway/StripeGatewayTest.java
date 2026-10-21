package com.example.zomato.gateway;

import com.example.zomato.entity.Customer;
import com.example.zomato.entity.Order;
import com.example.zomato.entity.Payment;
import com.example.zomato.entity.PaymentStatus;
import com.example.zomato.entity.Restaurant;
import com.example.zomato.entity.User;
import com.example.zomato.repository.CustomerRepository;
import com.example.zomato.repository.OrderRepository;
import com.example.zomato.repository.PaymentRepository;
import com.example.zomato.repository.RestaurantRepository;
import com.example.zomato.repository.UserRepository;
import com.example.zomato.services.PaymentService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
public class StripeGatewayTest {

    @Autowired
    private PaymentService paymentService;

    @Autowired
    private StripeGateway stripeGateway;

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private PaymentRepository paymentRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CustomerRepository customerRepository;

    @Autowired
    private RestaurantRepository restaurantRepository;

    private Order order;
    private Payment payment;

    @BeforeEach
    void setUp() {
        paymentRepository.deleteAll();
        orderRepository.deleteAll();

        User user = userRepository.findByEmail("gateway_user@cravey.com").orElseGet(() -> {
            User u = new User("GatewayUser", "gateway_user@cravey.com", "CUSTOMER");
            u.setPassword("Password123!");
            u.setEmailVerified(true);
            return userRepository.save(u);
        });

        Customer customer = customerRepository.findByEmail("gateway_user@cravey.com").orElseGet(() -> {
            Customer c = new Customer();
            c.setName("GatewayUser");
            c.setEmail("gateway_user@cravey.com");
            c.setAddress("123 Gateway Street");
            return customerRepository.save(c);
        });

        Restaurant restaurant = restaurantRepository.findAll().stream().findFirst().orElseGet(() -> {
            Restaurant r = new Restaurant();
            r.setName("Gateway Kitchen");
            return restaurantRepository.save(r);
        });

        order = new Order();
        order.setCustomer(customer);
        order.setRestaurant(restaurant);
        order.setOrderDate(LocalDateTime.now());
        order.setStatus("PLACED");
        order.setPaymentStatus(PaymentStatus.PAID);
        order.setTotalAmount(50.0);
        order = orderRepository.save(order);

        payment = new Payment();
        payment.setOrder(order);
        payment.setAmount(50.0);
        payment.setCurrency("inr");
        payment.setMethod("STRIPE");
        payment.setStatus("SUCCESS");
        payment.setTransactionId("pi_gateway_test_123");
        payment = paymentRepository.save(payment);
    }

    @Test
    void testProductionGatewayFailsStartupOnMissingOrMockKey() {
        DefaultStripeGateway gateway = new DefaultStripeGateway();

        // 1. Null key
        ReflectionTestUtils.setField(gateway, "secretKey", null);
        assertThrows(IllegalStateException.class, gateway::validateConfiguration);

        // 2. Blank key
        ReflectionTestUtils.setField(gateway, "secretKey", "   ");
        assertThrows(IllegalStateException.class, gateway::validateConfiguration);

        // 3. Mock key prefix
        ReflectionTestUtils.setField(gateway, "secretKey", "sk_test_mock_123");
        assertThrows(IllegalStateException.class, gateway::validateConfiguration);

        // 4. "mock"
        ReflectionTestUtils.setField(gateway, "secretKey", "mock");
        assertThrows(IllegalStateException.class, gateway::validateConfiguration);

        // 5. Valid real key format passes validation
        ReflectionTestUtils.setField(gateway, "secretKey", "sk_live_valid_production_key_12345");
        assertDoesNotThrow(gateway::validateConfiguration);
    }

    @Test
    void testRefundFailureLeavesOrderInRetryableState() throws Exception {
        assertTrue(stripeGateway instanceof FakeStripeGateway, "Test profile should use FakeStripeGateway");
        FakeStripeGateway fakeGateway = (FakeStripeGateway) stripeGateway;

        // Simulate gateway timeout / failure
        fakeGateway.setSimulateRefundFailure(true);

        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () ->
                paymentService.processRefund(order.getOrderId(), "Test refund failure"));
        assertEquals(502, ex.getStatusCode().value(), "Must return 502 Bad Gateway on Stripe refund failure");

        // Assert payment status is REFUND_FAILED (retryable state)
        Payment updatedPayment = paymentRepository.findById(payment.getId()).orElseThrow();
        assertEquals("REFUND_FAILED", updatedPayment.getStatus());

        // Assert order is NOT marked REFUNDED
        Order updatedOrder = orderRepository.findById(order.getOrderId()).orElseThrow();
        assertNotEquals(PaymentStatus.REFUNDED, updatedOrder.getPaymentStatus(),
                "Order must NOT be marked REFUNDED if refund failed");
        assertEquals(PaymentStatus.PAID, updatedOrder.getPaymentStatus());

        // Now simulate gateway recovery: retry should succeed
        fakeGateway.setSimulateRefundFailure(false);
        boolean retrySuccess = paymentService.processRefund(order.getOrderId(), "Retry refund after failure");
        assertTrue(retrySuccess);

        Payment finalPayment = paymentRepository.findById(payment.getId()).orElseThrow();
        assertEquals("REFUNDED", finalPayment.getStatus());

        Order finalOrder = orderRepository.findById(order.getOrderId()).orElseThrow();
        assertEquals(PaymentStatus.REFUNDED, finalOrder.getPaymentStatus());
        assertEquals("CANCELLED", finalOrder.getStatus());
    }
}
