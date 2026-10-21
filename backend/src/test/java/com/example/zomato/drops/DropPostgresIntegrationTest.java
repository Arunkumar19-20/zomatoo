package com.example.zomato.drops;

import com.example.zomato.dto.OrderResponseDTO;
import com.example.zomato.dto.ReservationResponseDTO;
import com.example.zomato.entity.*;
import com.example.zomato.exception.DropApiException;
import com.example.zomato.repository.*;
import com.example.zomato.services.DropService;
import com.example.zomato.services.OrderService;
import com.example.zomato.services.PaymentService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Random;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

@Tag("postgres")
@Testcontainers
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class DropPostgresIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("zomato_test")
            .withUsername("postgres")
            .withPassword("postgres");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.driverClassName", () -> "org.postgresql.Driver");
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
        registry.add("spring.jpa.database-platform", () -> "org.hibernate.dialect.PostgreSQLDialect");
        registry.add("spring.jpa.hibernate.ddl-auto", () -> "update");
        registry.add("spring.flyway.enabled", () -> "true");
        registry.add("spring.flyway.baseline-on-migrate", () -> "true");
    }

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
    @Autowired private JdbcTemplate jdbcTemplate;

    private TransactionTemplate transactionTemplate;
    private final String testWebhookSecret = "whsec_test_secret_postgres_suite_12345";
    private Restaurant restaurant;

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
                r.setName("Postgres Test Kitchen");
                r.setAddress("789 Elephant Rd");
                return restaurantRepository.save(r);
            });
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

    private void assertSlotInvariant(int dropId) {
        Drop d = dropRepository.findById(dropId).orElseThrow();
        long held = reservationRepository.countByDrop_IdAndStatus(dropId, ReservationStatus.HELD);
        long confirmed = reservationRepository.countByDrop_IdAndStatus(dropId, ReservationStatus.CONFIRMED);
        assertEquals(d.getReservedSlots(), held + confirmed,
                String.format("Invariant violation on Postgres for drop %d: reservedSlots=%d, held=%d, confirmed=%d",
                        dropId, d.getReservedSlots(), held, confirmed));
    }

    @Test
    void testPostgres_partialUniqueIndexExistsAndActiveInPostgres() {
        // Assert that the partial unique index was created and recognized in PostgreSQL pg_indexes
        List<String> indexes = jdbcTemplate.query(
                "SELECT indexname FROM pg_indexes WHERE tablename = 'drop_reservations' AND indexname = 'idx_drop_res_active_unique'",
                (rs, rowNum) -> rs.getString("indexname")
        );
        assertFalse(indexes.isEmpty(), "PostgreSQL must have idx_drop_res_active_unique index created");
    }

    @Test
    void testPostgres_50ConcurrentUsersReserveLastSlot_exactlyOneWins_andInvariantHolds() throws Exception {
        Drop singleSlotDrop = transactionTemplate.execute(status -> {
            Drop d = new Drop();
            d.setTitle("Postgres 50-User Race Drop");
            d.setPrice(75.0);
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
        AtomicInteger successfulReservations = new AtomicInteger();
        AtomicInteger soldOutErrors = new AtomicInteger();

        for (int i = 0; i < numUsers; i++) {
            String email = "pg_race_user_" + i + "@cravey.com";
            transactionTemplate.execute(status -> {
                ensureCustomerUser(email);
                return null;
            });
        }

        for (int i = 0; i < numUsers; i++) {
            final String email = "pg_race_user_" + i + "@cravey.com";
            pool.submit(() -> {
                try {
                    latch.await();
                    ReservationResponseDTO res = dropService.reserve(singleSlotDrop.getId(), email);
                    if (res != null && "HELD".equalsIgnoreCase(res.status())) {
                        successfulReservations.incrementAndGet();
                    }
                } catch (DropApiException ex) {
                    if ("SOLD_OUT".equals(ex.getCode())) {
                        soldOutErrors.incrementAndGet();
                    }
                } catch (Exception ignored) {
                }
            });
        }

        latch.countDown();
        pool.shutdown();
        assertTrue(pool.awaitTermination(20, TimeUnit.SECONDS));

        assertEquals(1, successfulReservations.get(), "On Postgres: exactly one user must win the single available slot");
        assertEquals(49, soldOutErrors.get(), "On Postgres: all 49 losing users must receive SOLD_OUT");

        assertSlotInvariant(singleSlotDrop.getId());
        assertEquals(1, dropRepository.findById(singleSlotDrop.getId()).orElseThrow().getReservedSlots());
    }

    @Test
    void testPostgres_twoTrulyConcurrentDeliveriesOfSameWebhookEvent_both200_exactlyOneProcessedRecord() throws Exception {
        Drop drop = transactionTemplate.execute(status -> {
            Drop d = new Drop();
            d.setTitle("Postgres Webhook Drop");
            d.setPrice(50.0);
            d.setTotalSlots(5);
            d.setReservedSlots(0);
            d.setRestaurantId(restaurant.getId());
            d.setStartsAt(LocalDateTime.now().minusMinutes(5));
            d.setEndsAt(LocalDateTime.now().plusHours(1));
            return dropRepository.save(d);
        });

        String userEmail = "pg_webhook_buyer@cravey.com";
        transactionTemplate.execute(status -> {
            ensureCustomerUser(userEmail);
            return null;
        });

        ReservationResponseDTO res = dropService.reserve(drop.getId(), userEmail);
        OrderResponseDTO order = orderService.checkoutDropDto(userEmail, res.reservationId());

        String eventId = "evt_pg_concurrent_123";
        String payload = createWebhookPayload(eventId, "payment_intent.succeeded", order.getOrderId(), 50.0, "pi_pg_123");
        String sig = buildSigHeader(payload);

        CyclicBarrier barrier = new CyclicBarrier(2);
        ExecutorService executor = Executors.newFixedThreadPool(2);

        Callable<Integer> deliveryTask = () -> {
            barrier.await(5, TimeUnit.SECONDS);
            MvcResult result = mockMvc.perform(post("/payment/webhook")
                            .header("Stripe-Signature", sig)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(payload))
                    .andReturn();
            return result.getResponse().getStatus();
        };

        Future<Integer> f1 = executor.submit(deliveryTask);
        Future<Integer> f2 = executor.submit(deliveryTask);

        int status1 = f1.get(10, TimeUnit.SECONDS);
        int status2 = f2.get(10, TimeUnit.SECONDS);
        executor.shutdown();

        assertEquals(200, status1);
        assertEquals(200, status2);

        assertEquals(1, processedWebhookEventRepository.count(), "Exactly one processed webhook event recorded in PostgreSQL");
        assertTrue(processedWebhookEventRepository.existsById(eventId));

        Order updatedOrder = orderRepository.findById(order.getOrderId()).orElseThrow();
        assertEquals(PaymentStatus.PAID, updatedOrder.getPaymentStatus());

        DropReservation updatedRes = reservationRepository.findById(res.reservationId()).orElseThrow();
        assertEquals(ReservationStatus.CONFIRMED, updatedRes.getStatus());
        assertSlotInvariant(drop.getId());
    }

    @Test
    void testPostgres_invariantHoldsAcrossRandomizedConcurrentOperations() throws Exception {
        Drop testDrop = transactionTemplate.execute(status -> {
            Drop d = new Drop();
            d.setTitle("Postgres Invariant Stress Drop");
            d.setPrice(30.0);
            d.setTotalSlots(10);
            d.setReservedSlots(0);
            d.setRestaurantId(restaurant.getId());
            d.setStartsAt(LocalDateTime.now().minusMinutes(10));
            d.setEndsAt(LocalDateTime.now().plusHours(2));
            return dropRepository.save(d);
        });

        int numWorkers = 8;
        int operationsPerWorker = 15;
        ExecutorService pool = Executors.newFixedThreadPool(numWorkers);
        CountDownLatch startLatch = new CountDownLatch(1);
        ConcurrentLinkedQueue<Integer> activeReservationIds = new ConcurrentLinkedQueue<>();
        ConcurrentLinkedQueue<Integer> paidOrderIds = new ConcurrentLinkedQueue<>();

        for (int i = 0; i < 20; i++) {
            String email = "pg_stress_user_" + i + "@cravey.com";
            transactionTemplate.execute(status -> {
                ensureCustomerUser(email);
                return null;
            });
        }

        for (int w = 0; w < numWorkers; w++) {
            final int workerId = w;
            pool.submit(() -> {
                Random rand = new Random(workerId * 1000L);
                try {
                    startLatch.await();
                    for (int op = 0; op < operationsPerWorker; op++) {
                        int choice = rand.nextInt(5);
                        String email = "pg_stress_user_" + rand.nextInt(20) + "@cravey.com";
                        try {
                            switch (choice) {
                                case 0 -> { // Reserve
                                    ReservationResponseDTO r = dropService.reserve(testDrop.getId(), email);
                                    if (r != null) {
                                        activeReservationIds.add(r.reservationId());
                                    }
                                }
                                case 1 -> { // Checkout & Pay
                                    Integer resId = activeReservationIds.poll();
                                    if (resId != null) {
                                        DropReservation r = reservationRepository.findById(resId).orElse(null);
                                        if (r != null && r.getStatus() == ReservationStatus.HELD && r.getOrderId() == null) {
                                            OrderResponseDTO o = orderService.checkoutDropDto(r.getCustomerEmail(), resId);
                                            if (o != null) {
                                                dropService.confirmByOrderId(o.getOrderId());
                                                paidOrderIds.add(o.getOrderId());
                                            }
                                        }
                                    }
                                }
                                case 2 -> { // Cancel / Refund
                                    Integer oId = paidOrderIds.poll();
                                    if (oId != null) {
                                        dropService.releaseByOrderId(oId);
                                    }
                                }
                                case 3 -> { // Release reservation
                                    Integer resId = activeReservationIds.poll();
                                    if (resId != null) {
                                        DropReservation r = reservationRepository.findById(resId).orElse(null);
                                        if (r != null) {
                                            dropService.release(resId, r.getCustomerEmail());
                                        }
                                    }
                                }
                                case 4 -> { // Expire sweep
                                    dropService.expireStaleHolds();
                                }
                            }
                        } catch (Exception ignored) {
                        }
                    }
                } catch (Exception ignored) {
                }
            });
        }

        startLatch.countDown();
        pool.shutdown();
        assertTrue(pool.awaitTermination(30, TimeUnit.SECONDS));

        // Invariant check on real PostgreSQL
        assertSlotInvariant(testDrop.getId());
    }
}
