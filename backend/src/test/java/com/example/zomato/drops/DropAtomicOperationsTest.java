package com.example.zomato.drops;

import com.example.zomato.dto.ReservationResponseDTO;
import com.example.zomato.entity.*;
import com.example.zomato.repository.DropRepository;
import com.example.zomato.repository.DropReservationRepository;
import com.example.zomato.repository.RestaurantRepository;
import com.example.zomato.services.DropService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;

import com.example.zomato.repository.CustomerRepository;
import com.example.zomato.repository.OrderRepository;
import com.example.zomato.repository.PaymentRepository;
import com.example.zomato.repository.UserRepository;
import com.example.zomato.services.OrderService;

import java.util.ArrayList;
import java.util.List;

@SpringBootTest
public class DropAtomicOperationsTest {

    @Autowired
    private DropService dropService;

    @Autowired
    private OrderService orderService;

    @Autowired
    private DropRepository dropRepository;

    @Autowired
    private DropReservationRepository reservationRepository;

    @Autowired
    private RestaurantRepository restaurantRepository;

    @Autowired
    private PaymentRepository paymentRepository;

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private CustomerRepository customerRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private org.springframework.transaction.PlatformTransactionManager transactionManager;

    private org.springframework.transaction.support.TransactionTemplate transactionTemplate;

    private Restaurant restaurant;
    private Drop drop;

    @BeforeEach
    void setUp() {
        transactionTemplate = new org.springframework.transaction.support.TransactionTemplate(transactionManager);
        transactionTemplate.execute(status -> {
            paymentRepository.deleteAll();
            reservationRepository.deleteAll();
            orderRepository.deleteAll();
            restaurant = restaurantRepository.findAll().stream().findFirst().orElseGet(() -> {
                Restaurant r = new Restaurant();
                r.setName("Atomic Ops Test Kitchen");
                return restaurantRepository.save(r);
            });

            for (String email : List.of("alice@cravey.com", "bob@cravey.com", "carol@cravey.com")) {
                userRepository.findByEmail(email).orElseGet(() -> {
                    User u = new User("User", email, "CUSTOMER");
                    u.setPassword("Password123!");
                    u.setEmailVerified(true);
                    return userRepository.save(u);
                });
                customerRepository.findByEmail(email).orElseGet(() -> {
                    Customer c = new Customer();
                    c.setName("Customer");
                    c.setEmail(email);
                    c.setAddress("123 Cravey Lane");
                    return customerRepository.save(c);
                });
            }

            Drop d = new Drop();
            d.setTitle("Atomic Burger Drop");
            d.setPrice(25.0);
            d.setTotalSlots(2);
            d.setReservedSlots(0);
            d.setRestaurantId(restaurant.getId());
            d.setStartsAt(LocalDateTime.now().minusMinutes(5));
            d.setEndsAt(LocalDateTime.now().plusHours(1));
            drop = dropRepository.save(d);
            return null;
        });
    }

    // --- Task 0: attachOrder tests ---

    @Test
    void testAttachOrderSuccess() {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@cravey.com");
        LocalDateTime beforeAttach = LocalDateTime.now();

        dropService.attachOrder(res.reservationId(), 1001, "alice@cravey.com");

        DropReservation updated = reservationRepository.findById(res.reservationId()).orElseThrow();
        assertEquals(1001, updated.getOrderId());
        assertEquals(ReservationStatus.HELD, updated.getStatus());
        assertTrue(updated.getExpiresAt().isAfter(beforeAttach.plusMinutes(25)),
                "Expiry should be extended by PAYMENT_WINDOW (30 min)");
    }

    @Test
    void testAttachOrderFailsWhenWrongUser() {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@cravey.com");

        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () ->
                dropService.attachOrder(res.reservationId(), 1002, "mallory@cravey.com"));
        assertEquals(403, ex.getStatusCode().value());
    }

    @Test
    void testAttachOrderFailsWhenNotFound() {
        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () ->
                dropService.attachOrder(999999, 1003, "alice@cravey.com"));
        assertEquals(404, ex.getStatusCode().value());
    }

    @Test
    void testAttachOrderFailsWhenExpired() {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@cravey.com");
        transactionTemplate.execute(status -> {
            DropReservation r = reservationRepository.findById(res.reservationId()).orElseThrow();
            r.setExpiresAt(LocalDateTime.now().minusMinutes(5));
            reservationRepository.saveAndFlush(r);
            return null;
        });

        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () ->
                dropService.attachOrder(res.reservationId(), 1004, "alice@cravey.com"));
        assertEquals(409, ex.getStatusCode().value());
    }

    @Test
    void testAttachOrderFailsWhenAlreadyHasOrderId() {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@cravey.com");
        dropService.attachOrder(res.reservationId(), 1005, "alice@cravey.com");

        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () ->
                dropService.attachOrder(res.reservationId(), 1006, "alice@cravey.com"));
        assertEquals(409, ex.getStatusCode().value());
    }

    @Test
    void testAttachOrderFailsWhenNotHeld() {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@cravey.com");
        dropService.release(res.reservationId(), "alice@cravey.com");

        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () ->
                dropService.attachOrder(res.reservationId(), 1007, "alice@cravey.com"));
        assertEquals(409, ex.getStatusCode().value());
    }

    // --- Task 0: Expiry scheduler race condition test ---

    @Test
    void testExpirySchedulerDoesNotExpireExtendedHold() {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@cravey.com");
        int resId = res.reservationId();

        // Attach order to extend hold by 30 minutes
        dropService.attachOrder(resId, 1008, "alice@cravey.com");

        // Run expiry scheduler
        int freed = dropService.expireStaleHolds();
        assertEquals(0, freed, "Should not expire an actively extended hold");

        DropReservation current = reservationRepository.findById(resId).orElseThrow();
        assertEquals(ReservationStatus.HELD, current.getStatus());
        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());
    }

    // --- Task 0: confirmByOrderId idempotency & concurrency tests ---

    @Test
    void testConfirmByOrderIdIdempotentAndSafe() {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@cravey.com");
        dropService.attachOrder(res.reservationId(), 1009, "alice@cravey.com");

        // First confirmation succeeds
        boolean firstConfirm = dropService.confirmByOrderId(1009);
        assertTrue(firstConfirm);

        DropReservation confirmed = reservationRepository.findById(res.reservationId()).orElseThrow();
        assertEquals(ReservationStatus.CONFIRMED, confirmed.getStatus());
        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());

        // Duplicate confirmation (replay from duplicate webhook delivery)
        boolean secondConfirm = dropService.confirmByOrderId(1009);
        assertTrue(secondConfirm);

        // Third confirmation
        boolean thirdConfirm = dropService.confirmByOrderId(1009);
        assertTrue(thirdConfirm);

        // Verify reserved slots count was not double-incremented
        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());
    }

    @Test
    void testConfirmByOrderIdNonDropOrderReturnsTrue() {
        // Non-drop order has no reservation record
        assertTrue(dropService.confirmByOrderId(987654));
    }

    @Test
    void testConfirmByOrderIdReclaimsSlotWhenExpiredAndAvailable() {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@cravey.com");
        int resId = res.reservationId();
        dropService.attachOrder(resId, 1010, "alice@cravey.com");

        // Simulate hold expiring and slot freed by scheduler
        transactionTemplate.execute(status -> {
            DropReservation r = reservationRepository.findById(resId).orElseThrow();
            r.setStatus(ReservationStatus.EXPIRED);
            reservationRepository.saveAndFlush(r);
            dropRepository.releaseSlot(drop.getId());
            return null;
        });
        assertEquals(0, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());

        // Now payment succeeds late. Slot is available, so re-claim should succeed
        boolean confirmed = dropService.confirmByOrderId(1010);
        assertTrue(confirmed);

        DropReservation reconfirmed = reservationRepository.findById(resId).orElseThrow();
        assertEquals(ReservationStatus.CONFIRMED, reconfirmed.getStatus());
        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());
    }

    @Test
    void testConfirmByOrderIdReclaimFailsWhenSoldOut() {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@cravey.com");
        int resId = res.reservationId();
        dropService.attachOrder(resId, 1011, "alice@cravey.com");

        // Simulate hold expiring and slot freed
        transactionTemplate.execute(status -> {
            DropReservation r = reservationRepository.findById(resId).orElseThrow();
            r.setStatus(ReservationStatus.EXPIRED);
            reservationRepository.saveAndFlush(r);
            dropRepository.releaseSlot(drop.getId());
            return null;
        });

        // Both available slots are now claimed by other users!
        dropService.reserve(drop.getId(), "bob@cravey.com");
        dropService.reserve(drop.getId(), "carol@cravey.com");
        assertEquals(2, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());

        // Now alice pays late: confirmByOrderId must return false without overselling
        boolean confirmed = dropService.confirmByOrderId(1011);
        assertFalse(confirmed, "Must return false when slot is lost");

        // Slot count remains 2 (no oversell)
        assertEquals(2, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());
    }

    // --- Task 0: releaseByOrderId at most once & concurrency tests ---

    @Test
    void testReleaseByOrderIdFreesSlotAtMostOnce() {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@cravey.com");
        int resId = res.reservationId();
        dropService.attachOrder(resId, 1012, "alice@cravey.com");
        dropService.confirmByOrderId(1012);

        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());

        // First release frees the slot
        dropService.releaseByOrderId(1012);
        assertEquals(0, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());
        DropReservation released = reservationRepository.findById(resId).orElseThrow();
        assertEquals(ReservationStatus.CANCELLED, released.getStatus());

        // Second release call (duplicate refund webhook or cancel+refund) changes nothing
        dropService.releaseByOrderId(1012);
        assertEquals(0, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots(),
                "Slot count must not become negative or decrement twice");
    }

    @Test
    void testConcurrentReleaseByOrderId() throws Exception {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@cravey.com");
        int resId = res.reservationId();
        dropService.attachOrder(resId, 1013, "alice@cravey.com");
        dropService.confirmByOrderId(1013);

        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());

        int threads = 20;
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        CountDownLatch latch = new CountDownLatch(1);

        for (int i = 0; i < threads; i++) {
            pool.submit(() -> {
                try {
                    latch.await();
                    dropService.releaseByOrderId(1013);
                } catch (Exception ignored) {
                }
            });
        }

        latch.countDown();
        pool.shutdown();
        assertTrue(pool.awaitTermination(10, TimeUnit.SECONDS));

        // Exactly 1 release must have occurred
        assertEquals(0, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots(),
                "Concurrent releases must only release the slot once");
    }

    @Test
    void testConcurrentConfirmByOrderId() throws Exception {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@cravey.com");
        int resId = res.reservationId();
        dropService.attachOrder(resId, 1014, "alice@cravey.com");

        int threads = 20;
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        CountDownLatch latch = new CountDownLatch(1);
        AtomicInteger successCount = new AtomicInteger();

        for (int i = 0; i < threads; i++) {
            pool.submit(() -> {
                try {
                    latch.await();
                    if (dropService.confirmByOrderId(1014)) {
                        successCount.incrementAndGet();
                    }
                } catch (Exception ignored) {
                }
            });
        }

        latch.countDown();
        pool.shutdown();
        assertTrue(pool.awaitTermination(10, TimeUnit.SECONDS));

        assertEquals(threads, successCount.get(), "All confirmation calls should succeed idempotently");
        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots(),
                "Reserved slots count must remain exactly 1");
    }

    // --- Task 1: Invariant and Leak Verification Tests ---

    @Test
    void testCancelUnpaidOrderRestoresAvailableSlots() {
        // 1. Reserve slot: increments reservedSlots (0 -> 1)
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@cravey.com");
        int resId = res.reservationId();
        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());
        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getAvailableSlots());

        // 2. Checkout: creates order in PLACED / PENDING status and attaches to reservation
        Order order = orderService.checkoutDrop("alice@cravey.com", resId);
        int orderId = order.getOrderId();
        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());

        // 3. Cancel unpaid order
        boolean cancelled = orderService.cancelOrder(orderId, "alice@cravey.com");
        assertTrue(cancelled);

        // 4. Assert slot is completely restored (disproving slot leak)
        Drop updatedDrop = dropRepository.findById(drop.getId()).orElseThrow();
        assertEquals(0, updatedDrop.getReservedSlots(), "Cancelling unpaid order must restore available slots (reservedSlots -> 0)");
        assertEquals(2, updatedDrop.getAvailableSlots());

        DropReservation updatedRes = reservationRepository.findById(resId).orElseThrow();
        assertEquals(ReservationStatus.CANCELLED, updatedRes.getStatus());

        // 5. Assert invariant: reservedSlots == count(HELD) + count(CONFIRMED)
        long activeCount = reservationRepository.countByDrop_IdAndStatusIn(
                drop.getId(), List.of(ReservationStatus.HELD, ReservationStatus.CONFIRMED));
        assertEquals(updatedDrop.getReservedSlots(), activeCount);
    }

    @Test
    void testReclaimPathAtomicityUnderConcurrentWebhooks() throws Exception {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "alice@cravey.com");
        int resId = res.reservationId();
        dropService.attachOrder(resId, 2001, "alice@cravey.com");

        // Simulate hold expiring and slot released by scheduler
        transactionTemplate.execute(status -> {
            DropReservation r = reservationRepository.findById(resId).orElseThrow();
            r.setStatus(ReservationStatus.EXPIRED);
            reservationRepository.saveAndFlush(r);
            dropRepository.releaseSlot(drop.getId());
            return null;
        });

        assertEquals(0, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());

        // Two or more simultaneous webhooks attempt late payment confirmation on the lapsed hold
        int threads = 10;
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        CountDownLatch latch = new CountDownLatch(1);
        AtomicInteger successCount = new AtomicInteger();

        for (int i = 0; i < threads; i++) {
            pool.submit(() -> {
                try {
                    latch.await();
                    if (dropService.confirmByOrderId(2001)) {
                        successCount.incrementAndGet();
                    }
                } catch (Exception ignored) {
                }
            });
        }

        latch.countDown();
        pool.shutdown();
        assertTrue(pool.awaitTermination(10, TimeUnit.SECONDS));

        assertEquals(threads, successCount.get(), "All webhooks return true (reclaim winner + idempotent replays)");
        Drop updatedDrop = dropRepository.findById(drop.getId()).orElseThrow();
        assertEquals(1, updatedDrop.getReservedSlots(), "Exactly 1 slot must be reclaimed; no double-increment");
        assertEquals(1, updatedDrop.getAvailableSlots());

        DropReservation finalRes = reservationRepository.findById(resId).orElseThrow();
        assertEquals(ReservationStatus.CONFIRMED, finalRes.getStatus());

        // Invariant holds
        long activeCount = reservationRepository.countByDrop_IdAndStatusIn(
                drop.getId(), List.of(ReservationStatus.HELD, ReservationStatus.CONFIRMED));
        assertEquals(updatedDrop.getReservedSlots(), activeCount);
    }

    @Test
    void testSlotAccountingInvariantRandomizedLifecycle() {
        Drop multiDrop = transactionTemplate.execute(status -> {
            Drop d = new Drop();
            d.setTitle("Invariant Multi Drop");
            d.setPrice(15.0);
            d.setTotalSlots(10);
            d.setReservedSlots(0);
            d.setRestaurantId(restaurant.getId());
            d.setStartsAt(LocalDateTime.now().minusMinutes(5));
            d.setEndsAt(LocalDateTime.now().plusHours(1));
            return dropRepository.save(d);
        });
        int dropId = multiDrop.getId();

        Runnable assertInvariant = () -> {
            Drop d = dropRepository.findById(dropId).orElseThrow();
            long activeReservations = reservationRepository.countByDrop_IdAndStatusIn(
                    dropId, List.of(ReservationStatus.HELD, ReservationStatus.CONFIRMED));
            assertEquals(d.getReservedSlots(), activeReservations,
                    "INVARIANT VIOLATION: reservedSlots (" + d.getReservedSlots() + ") != HELD+CONFIRMED (" + activeReservations + ")");
            assertTrue(d.getReservedSlots() >= 0, "reservedSlots cannot be negative: " + d.getReservedSlots());
            assertTrue(d.getReservedSlots() <= d.getTotalSlots(), "reservedSlots cannot exceed totalSlots: " + d.getReservedSlots());
        };

        // Assert initially
        assertInvariant.run();

        for (int i = 0; i < 20; i++) {
            String email = "inv_user_" + i + "@cravey.com";
            final String userEmail = email;
            transactionTemplate.execute(status -> {
                userRepository.findByEmail(userEmail).orElseGet(() -> {
                    User u = new User("InvUser", userEmail, "CUSTOMER");
                    u.setPassword("Password123!");
                    u.setEmailVerified(true);
                    return userRepository.save(u);
                });
                customerRepository.findByEmail(userEmail).orElseGet(() -> {
                    Customer c = new Customer();
                    c.setName("Customer");
                    c.setEmail(userEmail);
                    c.setAddress("123 Cravey Lane");
                    return customerRepository.save(c);
                });
                return null;
            });

            try {
                ReservationResponseDTO r = dropService.reserve(dropId, email);
                assertInvariant.run();

                if (i % 2 == 0) {
                    Order o = orderService.checkoutDrop(email, r.reservationId());
                    assertInvariant.run();

                    if (i % 4 == 0) {
                        dropService.confirmByOrderId(o.getOrderId());
                        assertInvariant.run();

                        if (i == 0) {
                            dropService.releaseByOrderId(o.getOrderId());
                            assertInvariant.run();
                        }
                    } else if (i % 4 == 2) {
                        orderService.cancelOrder(o.getOrderId(), email);
                        assertInvariant.run();
                    }
                } else if (i % 3 == 0) {
                    dropService.release(r.reservationId(), email);
                    assertInvariant.run();
                }
            } catch (ResponseStatusException ignored) {
                // Sold out is expected when cap is hit
                assertInvariant.run();
            }
        }

        // Expire stale holds
        dropService.expireStaleHolds();
        assertInvariant.run();
    }
}
