package com.example.zomato.drops;

import com.example.zomato.dto.OrderResponseDTO;
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
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
public class DropLifecycleIntegrationTest {

    @Autowired private MockMvc mockMvc;
    @Autowired private DropService dropService;
    @Autowired private DropRepository dropRepository;
    @Autowired private DropReservationRepository reservationRepository;
    @Autowired private OrderService orderService;
    @Autowired private OrderRepository orderRepository;
    @Autowired private PaymentService paymentService;
    @Autowired private PaymentRepository paymentRepository;
    @Autowired private UserRepository userRepository;
    @Autowired private RestaurantRepository restaurantRepository;
    @Autowired private ProcessedWebhookEventRepository processedWebhookEventRepository;
    @Autowired private PlatformTransactionManager transactionManager;

    private TransactionTemplate transactionTemplate;
    private final String testWebhookSecret = "whsec_test_secret_lifecycle_12345";
    private Restaurant restaurant;
    private Drop drop;

    @BeforeEach
    void setUp() {
        transactionTemplate = new TransactionTemplate(transactionManager);
        ReflectionTestUtils.setField(paymentService, "webhookSecret", testWebhookSecret);

        transactionTemplate.execute(status -> {
            processedWebhookEventRepository.deleteAll();
            paymentRepository.deleteAll();
            reservationRepository.deleteAll();
            orderRepository.deleteAll();

            restaurant = restaurantRepository.findAll().stream().findFirst().orElseGet(() -> {
                Restaurant r = new Restaurant();
                r.setName("Lifecycle Test Kitchen");
                r.setAddress("123 Gourmet Ave");
                return restaurantRepository.save(r);
            });

            Drop d = new Drop();
            d.setTitle("Truffle Caviar Burger Drop");
            d.setDescription("Limited batch luxury burger");
            d.setPrice(35.00);
            d.setTotalSlots(2);
            d.setReservedSlots(0);
            d.setRestaurantId(restaurant.getId());
            d.setStartsAt(LocalDateTime.now().minusMinutes(5));
            d.setEndsAt(LocalDateTime.now().plusHours(2));
            drop = dropRepository.save(d);

            ensureCustomerUser("alice@cravey.com");
            ensureCustomerUser("bob@cravey.com");
            ensureCustomerUser("carol@cravey.com");

            return null;
        });
    }

    private void ensureCustomerUser(String email) {
        userRepository.findByEmail(email).orElseGet(() -> {
            User u = new User("User", email, "CUSTOMER");
            u.setPassword("Password123!");
            u.setEmailVerified(true);
            return userRepository.save(u);
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

    private String buildSigHeader(String payload) throws Exception {
        long timestamp = System.currentTimeMillis() / 1000L;
        String signedPayload = timestamp + "." + payload;
        Mac sha256Hmac = Mac.getInstance("HmacSHA256");
        SecretKeySpec secretKey = new SecretKeySpec(testWebhookSecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
        sha256Hmac.init(secretKey);
        byte[] hash = sha256Hmac.doFinal(signedPayload.getBytes(StandardCharsets.UTF_8));
        StringBuilder result = new StringBuilder();
        for (byte b : hash) {
            result.append(String.format("%02x", b));
        }
        return "t=" + timestamp + ",v1=" + result.toString();
    }

    // 1. reserve -> checkout -> pay -> confirmed
    @Test
    void testScenario1_reserve_checkout_pay_confirmed() throws Exception {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@cravey.com");
        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());

        OrderResponseDTO order = orderService.checkoutDropDto("alice@cravey.com", res.reservationId());
        assertNotNull(order);
        assertEquals("PLACED", order.getStatus());
        assertEquals(PaymentStatus.PENDING, order.getPaymentStatus());
        assertEquals(35.00, order.getTotalAmount(), 0.01);

        String payload = createWebhookPayload("evt_s1", "payment_intent.succeeded", order.getOrderId(), 35.0, "pi_s1");
        mockMvc.perform(post("/payment/webhook")
                        .header("Stripe-Signature", buildSigHeader(payload))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk());

        DropReservation confirmedRes = reservationRepository.findById(res.reservationId()).orElseThrow();
        assertEquals(ReservationStatus.CONFIRMED, confirmedRes.getStatus());
        assertEquals(PaymentStatus.PAID, orderRepository.findById(order.getOrderId()).orElseThrow().getPaymentStatus());
        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());
    }

    // 2. reserve -> hold expires -> pay -> re-claim succeeds (slot free)
    @Test
    void testScenario2_reserve_holdExpires_pay_reclaimSucceeds() throws Exception {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@cravey.com");
        OrderResponseDTO order = orderService.checkoutDropDto("alice@cravey.com", res.reservationId());

        // Simulate hold expiring and scheduler freeing the slot
        transactionTemplate.execute(status -> {
            DropReservation r = reservationRepository.findById(res.reservationId()).orElseThrow();
            r.setStatus(ReservationStatus.EXPIRED);
            reservationRepository.saveAndFlush(r);
            dropRepository.releaseSlot(drop.getId());
            return null;
        });
        assertEquals(0, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());

        // Payment succeeds late -> re-claim slot succeeds
        String payload = createWebhookPayload("evt_s2", "payment_intent.succeeded", order.getOrderId(), 35.0, "pi_s2");
        mockMvc.perform(post("/payment/webhook")
                        .header("Stripe-Signature", buildSigHeader(payload))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk());

        DropReservation reconfirmed = reservationRepository.findById(res.reservationId()).orElseThrow();
        assertEquals(ReservationStatus.CONFIRMED, reconfirmed.getStatus());
        assertEquals(PaymentStatus.PAID, orderRepository.findById(order.getOrderId()).orElseThrow().getPaymentStatus());
        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());
    }

    // 3. reserve -> hold expires -> another user takes the last slot -> pay -> confirm false -> refund triggered, slot count unchanged
    @Test
    void testScenario3_reserve_holdExpires_anotherTakesLastSlot_pay_confirmFalse_refundTriggered() throws Exception {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@cravey.com");
        OrderResponseDTO order = orderService.checkoutDropDto("alice@cravey.com", res.reservationId());

        // Hold expires and slot freed
        transactionTemplate.execute(status -> {
            DropReservation r = reservationRepository.findById(res.reservationId()).orElseThrow();
            r.setStatus(ReservationStatus.EXPIRED);
            reservationRepository.saveAndFlush(r);
            dropRepository.releaseSlot(drop.getId());
            return null;
        });

        // Other users take all 2 slots (drop is now sold out)
        dropService.reserve(drop.getId(), "bob@cravey.com");
        dropService.reserve(drop.getId(), "carol@cravey.com");
        assertEquals(2, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());

        // Alice pays late -> confirmByOrderId returns false -> automatic refund triggered
        String payload = createWebhookPayload("evt_s3", "payment_intent.succeeded", order.getOrderId(), 35.0, "pi_s3");
        mockMvc.perform(post("/payment/webhook")
                        .header("Stripe-Signature", buildSigHeader(payload))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk());

        Order refundedOrder = orderRepository.findById(order.getOrderId()).orElseThrow();
        assertEquals(PaymentStatus.REFUNDED, refundedOrder.getPaymentStatus());
        assertEquals("CANCELLED", refundedOrder.getStatus());
        // Slot count unchanged (no oversell)
        assertEquals(2, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());
    }

    // 4. reserve -> checkout -> refund -> slot released once; second refund call changes nothing
    @Test
    void testScenario4_reserve_checkout_refund_slotReleasedOnce_secondRefundChangesNothing() throws Exception {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@cravey.com");
        OrderResponseDTO order = orderService.checkoutDropDto("alice@cravey.com", res.reservationId());

        String payload = createWebhookPayload("evt_s4", "payment_intent.succeeded", order.getOrderId(), 35.0, "pi_s4");
        mockMvc.perform(post("/payment/webhook")
                        .header("Stripe-Signature", buildSigHeader(payload))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk());
        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());

        // First refund
        boolean firstRefund = paymentService.processRefund(order.getOrderId(), "Customer cancellation");
        assertTrue(firstRefund);
        assertEquals(0, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());
        assertEquals(ReservationStatus.CANCELLED, reservationRepository.findById(res.reservationId()).orElseThrow().getStatus());

        // Second refund call changes nothing
        boolean secondRefund = paymentService.processRefund(order.getOrderId(), "Duplicate refund");
        assertTrue(secondRefund);
        assertEquals(0, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots(),
                "Second refund must never double-release slot");
    }

    // 5. duplicate payment_succeeded webhook -> no double effect
    @Test
    void testScenario5_duplicatePaymentSucceededWebhook_noDoubleEffect() throws Exception {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@cravey.com");
        OrderResponseDTO order = orderService.checkoutDropDto("alice@cravey.com", res.reservationId());

        String eventId = "evt_s5_dup";
        String payload = createWebhookPayload(eventId, "payment_intent.succeeded", order.getOrderId(), 35.0, "pi_s5");
        String sig = buildSigHeader(payload);

        // First delivery
        mockMvc.perform(post("/payment/webhook")
                        .header("Stripe-Signature", sig)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk());

        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());
        assertEquals(ReservationStatus.CONFIRMED, reservationRepository.findById(res.reservationId()).orElseThrow().getStatus());

        // Replay same webhook
        mockMvc.perform(post("/payment/webhook")
                        .header("Stripe-Signature", sig)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk());

        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());
        assertEquals(ReservationStatus.CONFIRMED, reservationRepository.findById(res.reservationId()).orElseThrow().getStatus());
        assertEquals(1, processedWebhookEventRepository.count());
    }

    // 6. payment_failed -> hold remains
    @Test
    void testScenario6_paymentFailed_holdRemains() throws Exception {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@cravey.com");
        OrderResponseDTO order = orderService.checkoutDropDto("alice@cravey.com", res.reservationId());

        transactionTemplate.execute(status -> {
            Payment p = new Payment();
            p.setOrder(orderRepository.findById(order.getOrderId()).orElseThrow());
            p.setAmount(35.0);
            p.setCurrency("inr");
            p.setMethod("STRIPE");
            p.setStatus("PENDING");
            p.setTransactionId("pi_s6_fail");
            paymentRepository.save(p);
            return null;
        });

        String payload = createWebhookPayload("evt_s6", "payment_intent.payment_failed", order.getOrderId(), 35.0, "pi_s6_fail");
        mockMvc.perform(post("/payment/webhook")
                        .header("Stripe-Signature", buildSigHeader(payload))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk());

        // Hold MUST remain intact
        assertEquals(ReservationStatus.HELD, reservationRepository.findById(res.reservationId()).orElseThrow().getStatus());
        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());
    }

    // 7. 50 concurrent checkouts for the last slot -> exactly one wins
    @Test
    void testScenario7_50ConcurrentCheckoutsForLastSlot_exactlyOneWins() throws Exception {
        // Create drop with totalSlots = 1
        Drop singleSlotDrop = transactionTemplate.execute(status -> {
            Drop d = new Drop();
            d.setTitle("Last Slot Winner Drop");
            d.setPrice(50.0);
            d.setTotalSlots(1);
            d.setReservedSlots(0);
            d.setRestaurantId(restaurant.getId());
            d.setStartsAt(LocalDateTime.now().minusMinutes(1));
            d.setEndsAt(LocalDateTime.now().plusHours(1));
            return dropRepository.save(d);
        });

        int numUsers = 50;
        ExecutorService pool = Executors.newFixedThreadPool(16);
        CountDownLatch latch = new CountDownLatch(1);
        AtomicInteger successfulCheckouts = new AtomicInteger();

        // Ensure users exist
        for (int i = 0; i < numUsers; i++) {
            String email = "conc_user_" + i + "@cravey.com";
            transactionTemplate.execute(status -> {
                ensureCustomerUser(email);
                return null;
            });
        }

        for (int i = 0; i < numUsers; i++) {
            final String email = "conc_user_" + i + "@cravey.com";
            pool.submit(() -> {
                try {
                    latch.await();
                    // Attempt to reserve and checkout
                    ReservationResponseDTO res = dropService.reserve(singleSlotDrop.getId(), email);
                    OrderResponseDTO order = orderService.checkoutDropDto(email, res.reservationId());
                    if (order != null) {
                        successfulCheckouts.incrementAndGet();
                    }
                } catch (Exception ignored) {
                }
            });
        }

        latch.countDown();
        pool.shutdown();
        assertTrue(pool.awaitTermination(20, TimeUnit.SECONDS));

        // EXACTLY 1 user must win the slot and create the order
        assertEquals(1, successfulCheckouts.get(), "Exactly one user must win the single available slot");
        assertEquals(1, dropRepository.findById(singleSlotDrop.getId()).orElseThrow().getReservedSlots(),
                "Reserved slots must be exactly 1");
    }
}
