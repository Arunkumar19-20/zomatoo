package com.example.zomato.drops;

import com.example.zomato.dto.ReservationResponseDTO;
import com.example.zomato.entity.*;
import com.example.zomato.repository.*;
import com.example.zomato.services.DropService;
import com.example.zomato.services.OrderService;
import com.example.zomato.services.PaymentService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
public class PaymentServiceDropIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private PaymentService paymentService;

    @Autowired
    private OrderService orderService;

    @Autowired
    private DropService dropService;

    @Autowired
    private DropRepository dropRepository;

    @Autowired
    private DropReservationRepository reservationRepository;

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private PaymentRepository paymentRepository;

    @Autowired
    private CustomerRepository customerRepository;

    @Autowired
    private RestaurantRepository restaurantRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ProcessedWebhookEventRepository processedWebhookEventRepository;

    @Autowired
    private PlatformTransactionManager transactionManager;

    private TransactionTemplate transactionTemplate;
    private Restaurant restaurant;
    private Drop drop;
    private Customer customer;
    private User customerUser;
    private final String testWebhookSecret = "whsec_test_secret_task1_123456789";

    @BeforeEach
    void setUp() {
        transactionTemplate = new TransactionTemplate(transactionManager);
        ReflectionTestUtils.setField(paymentService, "webhookSecret", testWebhookSecret);

        transactionTemplate.execute(status -> {
            processedWebhookEventRepository.deleteAll();
            paymentRepository.deleteAll();
            reservationRepository.deleteAll();
            orderRepository.deleteAll();

            customerUser = userRepository.findByEmail("customer@cravey.com").orElseGet(() -> {
                User u = new User("Customer", "customer@cravey.com", "CUSTOMER");
                u.setPassword("Password123!");
                u.setEmailVerified(true);
                return userRepository.save(u);
            });

            customer = customerRepository.findByEmail("customer@cravey.com").orElseGet(() -> {
                Customer c = new Customer();
                c.setName("Customer");
                c.setEmail("customer@cravey.com");
                c.setAddress("123 Food Street");
                c.setUserId(customerUser.getUserId());
                return customerRepository.save(c);
            });

            restaurant = restaurantRepository.findAll().stream().findFirst().orElseGet(() -> {
                Restaurant r = new Restaurant();
                r.setName("Payment Drop Kitchen");
                return restaurantRepository.save(r);
            });

            Drop d = new Drop();
            d.setTitle("Payment Test Burger Drop");
            d.setPrice(30.0);
            d.setTotalSlots(2);
            d.setReservedSlots(0);
            d.setRestaurantId(restaurant.getId());
            d.setStartsAt(LocalDateTime.now().minusMinutes(5));
            d.setEndsAt(LocalDateTime.now().plusHours(1));
            drop = dropRepository.save(d);

            return null;
        });
    }

    private String createWebhookPayload(String eventId, String type, int orderId, double amountInUnits, String paymentIntentId) {
        long amountInCents = Math.round(amountInUnits * 100);
        return String.format("""
            {
              "id": "%s",
              "type": "%s",
              "api_version": "%s",
              "data": {
                "object": {
                  "id": "%s",
                  "object": "payment_intent",
                  "amount": %d,
                  "currency": "inr",
                  "status": "succeeded",
                  "metadata": {
                    "orderId": "%d"
                  }
                }
              }
            }
            """, eventId, type, com.stripe.Stripe.API_VERSION, paymentIntentId, amountInCents, orderId);
    }

    private String computeHmacSha256(String key, String data) throws Exception {
        Mac sha256Hmac = Mac.getInstance("HmacSHA256");
        SecretKeySpec secretKey = new SecretKeySpec(key.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
        sha256Hmac.init(secretKey);
        byte[] hash = sha256Hmac.doFinal(data.getBytes(StandardCharsets.UTF_8));
        StringBuilder result = new StringBuilder();
        for (byte b : hash) {
            result.append(String.format("%02x", b));
        }
        return result.toString();
    }

    private String buildSigHeader(String payload) throws Exception {
        long timestamp = System.currentTimeMillis() / 1000L;
        String signedPayload = timestamp + "." + payload;
        String signature = computeHmacSha256(testWebhookSecret, signedPayload);
        return "t=" + timestamp + ",v1=" + signature;
    }

    @Test
    void testPaymentSucceededConfirmsDropReservation() throws Exception {
        // 1. Reserve slot
        ReservationResponseDTO res = dropService.reserve(drop.getId(), customerUser.getEmail());
        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());

        // 2. Checkout drop
        Order order = orderService.checkoutDrop(customerUser.getEmail(), res.reservationId());
        int orderId = order.getOrderId();

        // 3. Deliver Stripe payment_intent.succeeded webhook
        String eventId = "evt_drop_success_1";
        String payload = createWebhookPayload(eventId, "payment_intent.succeeded", orderId, 30.0, "pi_drop_1");
        String sigHeader = buildSigHeader(payload);

        mockMvc.perform(post("/payment/webhook")
                        .header("Stripe-Signature", sigHeader)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk());

        // 4. Verify reservation is CONFIRMED and order is PAID
        DropReservation confirmedRes = reservationRepository.findById(res.reservationId()).orElseThrow();
        assertEquals(ReservationStatus.CONFIRMED, confirmedRes.getStatus());

        Order savedOrder = orderRepository.findById(orderId).orElseThrow();
        assertEquals(PaymentStatus.PAID, savedOrder.getPaymentStatus());
        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());
    }

    @Test
    void testPaymentSucceededWithLostSlotTriggersRefundAndMarksCancelled() throws Exception {
        // 1. Reserve slot
        ReservationResponseDTO res = dropService.reserve(drop.getId(), customerUser.getEmail());
        Order order = orderService.checkoutDrop(customerUser.getEmail(), res.reservationId());
        int orderId = order.getOrderId();

        // 2. Simulate hold expiration and another user taking the last slot
        transactionTemplate.execute(status -> {
            DropReservation r = reservationRepository.findById(res.reservationId()).orElseThrow();
            r.setStatus(ReservationStatus.EXPIRED);
            reservationRepository.saveAndFlush(r);
            dropRepository.releaseSlot(drop.getId());
            return null;
        });

        // 2 users claim all slots (drop has totalSlots = 2)
        dropService.reserve(drop.getId(), "other1@cravey.com");
        dropService.reserve(drop.getId(), "other2@cravey.com");
        assertEquals(2, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());

        // 3. Late payment arrives via webhook
        String eventId = "evt_drop_lost_slot_1";
        String payload = createWebhookPayload(eventId, "payment_intent.succeeded", orderId, 30.0, "pi_drop_lost");
        String sigHeader = buildSigHeader(payload);

        mockMvc.perform(post("/payment/webhook")
                        .header("Stripe-Signature", sigHeader)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk());

        // 4. Verify order is REFUNDED and CANCELLED, and no overselling occurred
        Order savedOrder = orderRepository.findById(orderId).orElseThrow();
        assertEquals(PaymentStatus.REFUNDED, savedOrder.getPaymentStatus());
        assertEquals("CANCELLED", savedOrder.getStatus());
        assertEquals(2, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());
    }

    @Test
    void testProcessRefundReleasesConfirmedDropSlot() throws Exception {
        // Reserve, checkout, pay
        ReservationResponseDTO res = dropService.reserve(drop.getId(), customerUser.getEmail());
        Order order = orderService.checkoutDrop(customerUser.getEmail(), res.reservationId());
        int orderId = order.getOrderId();

        String payload = createWebhookPayload("evt_refund_test", "payment_intent.succeeded", orderId, 30.0, "pi_drop_refund");
        mockMvc.perform(post("/payment/webhook")
                        .header("Stripe-Signature", buildSigHeader(payload))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk());

        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());

        // Process refund
        boolean refunded = paymentService.processRefund(orderId, "customer request");
        assertTrue(refunded);

        // Slot freed
        assertEquals(0, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());
        DropReservation r = reservationRepository.findById(res.reservationId()).orElseThrow();
        assertEquals(ReservationStatus.RELEASED, r.getStatus());

        // Second refund call does NOT double-release
        boolean secondRefund = paymentService.processRefund(orderId, "duplicate request");
        assertTrue(secondRefund);
        assertEquals(0, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());
    }

    @Test
    void testOrderCancellationReleasesHeldDropSlot() {
        // Reserve and checkout (unpaid order, status=PLACED, paymentStatus=PENDING)
        ReservationResponseDTO res = dropService.reserve(drop.getId(), customerUser.getEmail());
        Order order = orderService.checkoutDrop(customerUser.getEmail(), res.reservationId());
        int orderId = order.getOrderId();

        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());

        // Cancel order while unpaid
        boolean cancelled = orderService.cancelOrder(orderId, customerUser.getEmail());
        assertTrue(cancelled);

        // Slot released
        assertEquals(0, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());
        DropReservation r = reservationRepository.findById(res.reservationId()).orElseThrow();
        assertEquals(ReservationStatus.RELEASED, r.getStatus());
    }

    @Test
    void testPaymentFailedDoesNotReleaseHold() throws Exception {
        // Reserve and checkout
        ReservationResponseDTO res = dropService.reserve(drop.getId(), customerUser.getEmail());
        Order order = orderService.checkoutDrop(customerUser.getEmail(), res.reservationId());
        int orderId = order.getOrderId();

        // Create pending payment record
        transactionTemplate.execute(status -> {
            Payment p = new Payment();
            p.setOrder(order);
            p.setAmount(30.0);
            p.setCurrency("inr");
            p.setMethod("STRIPE");
            p.setStatus("PENDING");
            p.setTransactionId("pi_failed_retry_test");
            paymentRepository.save(p);
            return null;
        });

        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());

        // Deliver payment_failed webhook
        String eventId = "evt_drop_failed_retry";
        String payload = createWebhookPayload(eventId, "payment_intent.payment_failed", orderId, 30.0, "pi_failed_retry_test");
        mockMvc.perform(post("/payment/webhook")
                        .header("Stripe-Signature", buildSigHeader(payload))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk());

        // Hold MUST remain intact for customer payment retry
        DropReservation r = reservationRepository.findById(res.reservationId()).orElseThrow();
        assertEquals(ReservationStatus.HELD, r.getStatus(), "Hold must NOT be released on payment failure");
        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());
    }

    @Test
    void testDuplicatePaymentSucceededWebhookIsIdempotent() throws Exception {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), customerUser.getEmail());
        Order order = orderService.checkoutDrop(customerUser.getEmail(), res.reservationId());
        int orderId = order.getOrderId();

        String eventId = "evt_duplicate_delivery";
        String payload = createWebhookPayload(eventId, "payment_intent.succeeded", orderId, 30.0, "pi_dup_test");
        String sigHeader = buildSigHeader(payload);

        // First delivery
        mockMvc.perform(post("/payment/webhook")
                        .header("Stripe-Signature", sigHeader)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk());

        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());
        assertEquals(ReservationStatus.CONFIRMED, reservationRepository.findById(res.reservationId()).orElseThrow().getStatus());

        // Duplicate delivery (same event ID)
        mockMvc.perform(post("/payment/webhook")
                        .header("Stripe-Signature", sigHeader)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk());

        // Assert no double-effect: slots and reservation state unchanged
        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());
        assertEquals(ReservationStatus.CONFIRMED, reservationRepository.findById(res.reservationId()).orElseThrow().getStatus());
        assertEquals(1, processedWebhookEventRepository.count());
    }
}
