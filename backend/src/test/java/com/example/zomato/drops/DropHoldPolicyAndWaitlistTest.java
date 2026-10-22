package com.example.zomato.drops;

import com.example.zomato.dto.ReservationResponseDTO;
import com.example.zomato.dto.WaitlistEntryResponseDTO;
import com.example.zomato.entity.*;
import com.example.zomato.exception.DropApiException;
import com.example.zomato.gateway.FakeStripeGateway;
import com.example.zomato.repository.*;
import com.example.zomato.security.JwtService;
import com.example.zomato.services.DropService;
import com.example.zomato.services.OrderService;
import com.example.zomato.services.PaymentService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
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
import java.util.List;

import static org.hamcrest.Matchers.hasSize;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * One timer rule (10 min hold, >=5 min once paying, payment-aware extension, 20 min hard cap),
 * order cleanup, refund retries and the FIFO waitlist with slot hand-off.
 */
@SpringBootTest
@AutoConfigureMockMvc
public class DropHoldPolicyAndWaitlistTest {

    private static final String ALICE = "hp_alice@cravey.com";
    private static final String BOB = "hp_bob@cravey.com";
    private static final String CAROL = "hp_carol@cravey.com";
    private static final String WEBHOOK_SECRET = "whsec_hold_policy_suite_123";

    @Autowired private MockMvc mockMvc;
    @Autowired private JwtService jwtService;
    @Autowired private DropService dropService;
    @Autowired private OrderService orderService;
    @Autowired private PaymentService paymentService;
    @Autowired private FakeStripeGateway fakeStripe;
    @Autowired private DropRepository dropRepository;
    @Autowired private DropReservationRepository reservationRepository;
    @Autowired private DropWaitlistRepository waitlistRepository;
    @Autowired private OrderRepository orderRepository;
    @Autowired private PaymentRepository paymentRepository;
    @Autowired private ProcessedWebhookEventRepository processedWebhookEventRepository;
    @Autowired private UserRepository userRepository;
    @Autowired private CustomerRepository customerRepository;
    @Autowired private RestaurantRepository restaurantRepository;
    @Autowired private NotificationRepository notificationRepository;
    @Autowired private PlatformTransactionManager transactionManager;

    private TransactionTemplate tx;
    private Restaurant restaurant;
    private Drop drop;

    @BeforeEach
    void setUp() {
        tx = new TransactionTemplate(transactionManager);
        ReflectionTestUtils.setField(paymentService, "webhookSecret", WEBHOOK_SECRET);
        tx.execute(status -> {
            processedWebhookEventRepository.deleteAll();
            paymentRepository.deleteAll();
            notificationRepository.deleteAll();
            waitlistRepository.deleteAll();
            reservationRepository.deleteAll();
            orderRepository.deleteAll();

            for (String email : List.of(ALICE, BOB, CAROL)) {
                User u = userRepository.findByEmail(email).orElseGet(() -> {
                    User created = new User("User", email, "CUSTOMER");
                    created.setPassword("Password123!");
                    created.setEmailVerified(true);
                    return userRepository.save(created);
                });
                customerRepository.findByEmail(email).orElseGet(() -> {
                    Customer c = new Customer();
                    c.setName("Customer");
                    c.setEmail(email);
                    c.setAddress("1 Cravey Lane");
                    c.setUserId(u.getUserId());
                    return customerRepository.save(c);
                });
            }

            restaurant = restaurantRepository.findAll().stream().findFirst().orElseGet(() -> {
                Restaurant r = new Restaurant();
                r.setName("Hold Policy Kitchen");
                return restaurantRepository.save(r);
            });
            return null;
        });
        drop = newDrop(1);
    }

    @AfterEach
    void tearDown() {
        fakeStripe.setSimulateRefundFailure(false);
    }

    // ------------------------------------------------------------------ helpers

    private Drop newDrop(int slots) {
        return tx.execute(status -> {
            Drop d = new Drop();
            d.setTitle("Hold Policy Drop");
            d.setPrice(30.0);
            d.setTotalSlots(slots);
            d.setReservedSlots(0);
            d.setRestaurantId(restaurant.getId());
            d.setStartsAt(LocalDateTime.now().minusMinutes(5));
            d.setEndsAt(LocalDateTime.now().plusHours(1));
            return dropRepository.save(d);
        });
    }

    private int reservedSlots() {
        return dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots();
    }

    private void assertInvariant() {
        long active = reservationRepository.countByDrop_IdAndStatusIn(
                drop.getId(), List.of(ReservationStatus.HELD, ReservationStatus.CONFIRMED));
        assertEquals(reservedSlots(), active, "reservedSlots must equal count(HELD)+count(CONFIRMED)");
        assertTrue(reservedSlots() <= dropRepository.findById(drop.getId()).orElseThrow().getTotalSlots());
    }

    private void setTimes(int reservationId, LocalDateTime createdAt, LocalDateTime expiresAt) {
        tx.execute(status -> {
            DropReservation r = reservationRepository.findById(reservationId).orElseThrow();
            if (createdAt != null) r.setCreatedAt(createdAt);
            if (expiresAt != null) r.setExpiresAt(expiresAt);
            reservationRepository.saveAndFlush(r);
            return null;
        });
    }

    private DropReservation reservation(int id) {
        return reservationRepository.findById(id).orElseThrow();
    }

    private DropReservation activeReservationOf(String email) {
        return reservationRepository.findByDrop_IdAndCustomerEmailAndStatusIn(
                drop.getId(), email, List.of(ReservationStatus.HELD, ReservationStatus.CONFIRMED)).get(0);
    }

    private String webhookPayload(String eventId, String type, int orderId, double amount, String intentId) {
        return String.format("""
            {"id":"%s","type":"%s","api_version":"%s","data":{"object":{"id":"%s","object":"payment_intent",
            "amount":%d,"currency":"inr","status":"succeeded","metadata":{"orderId":"%d"}}}}
            """, eventId, type, com.stripe.Stripe.API_VERSION, intentId, Math.round(amount * 100), orderId);
    }

    private void sendWebhook(String payload) throws Exception {
        long ts = System.currentTimeMillis() / 1000L;
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(WEBHOOK_SECRET.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
        StringBuilder hex = new StringBuilder();
        for (byte b : mac.doFinal((ts + "." + payload).getBytes(StandardCharsets.UTF_8))) hex.append(String.format("%02x", b));
        mockMvc.perform(post("/payment/webhook")
                        .header("Stripe-Signature", "t=" + ts + ",v1=" + hex)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk());
    }

    // ------------------------------------------------------------- timer rule

    @Test
    @DisplayName("Reserve holds for 10 minutes; checkout never shortens it and guarantees >= 5 minutes")
    void holdFollowsOneTimerRule() {
        LocalDateTime before = LocalDateTime.now();
        ReservationResponseDTO res = dropService.reserve(drop.getId(), ALICE);
        assertFalse(res.expiresAt().isBefore(before.plusMinutes(10).minusSeconds(2)));
        assertFalse(res.expiresAt().isAfter(before.plusMinutes(10).plusSeconds(5)));

        // 1 minute left when checkout starts -> topped up to 5 minutes
        setTimes(res.reservationId(), null, LocalDateTime.now().plusMinutes(1));
        Order order = orderService.checkoutDrop(ALICE, res.reservationId());
        LocalDateTime afterAttach = reservation(res.reservationId()).getExpiresAt();
        assertEquals(order.getOrderId(), reservation(res.reservationId()).getOrderId());
        assertTrue(afterAttach.isAfter(LocalDateTime.now().plusMinutes(4).plusSeconds(50)));
        assertTrue(afterAttach.isBefore(LocalDateTime.now().plusMinutes(5).plusSeconds(5)));
    }

    @Test
    @DisplayName("Payment in flight extends the hold, but never past the 20 minute hard cap")
    void paymentInFlightExtendsHoldWithinHardCap() throws Exception {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), ALICE);
        Order order = orderService.checkoutDrop(ALICE, res.reservationId());
        int orderId = order.getOrderId();

        setTimes(res.reservationId(), null, LocalDateTime.now().plusSeconds(30));
        paymentService.createPaymentIntent(orderId, ALICE); // customer taps Pay
        LocalDateTime extended = reservation(res.reservationId()).getExpiresAt();
        assertTrue(extended.isAfter(LocalDateTime.now().plusMinutes(4).plusSeconds(50)), "grace of ~5 minutes");

        // 19 minutes into the hold: the grace is clipped to createdAt + 20 minutes
        LocalDateTime created = LocalDateTime.now().minusMinutes(19);
        setTimes(res.reservationId(), created, LocalDateTime.now().plusSeconds(10));
        assertTrue(dropService.extendHoldForPayment(orderId));
        LocalDateTime capped = reservation(res.reservationId()).getExpiresAt();
        assertFalse(capped.isAfter(created.plusMinutes(20).plusSeconds(1)), "hard cap");
        assertTrue(capped.isAfter(LocalDateTime.now().plusSeconds(10)));

        // At the cap nothing more can be gained
        setTimes(res.reservationId(), LocalDateTime.now().minusMinutes(21), LocalDateTime.now().plusSeconds(5));
        assertFalse(dropService.extendHoldForPayment(orderId));
    }

    @Test
    @DisplayName("Stripe 'processing' webhook keeps an about-to-expire hold alive; sweeper leaves it alone")
    void processingWebhookProtectsHoldFromSweeper() throws Exception {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), ALICE);
        Order order = orderService.checkoutDrop(ALICE, res.reservationId());
        setTimes(res.reservationId(), null, LocalDateTime.now().minusSeconds(20)); // lapsed, sweeper has not run yet

        sendWebhook(webhookPayload("evt_processing_1", "payment_intent.processing", order.getOrderId(), 30.0, "pi_proc_1"));

        assertEquals(0, dropService.expireStaleHolds(), "extended hold must not be expired");
        assertEquals(ReservationStatus.HELD, reservation(res.reservationId()).getStatus());
        assertEquals(1, reservedSlots());
        assertInvariant();
    }

    @Test
    @DisplayName("An expired hold cancels its unpaid order and frees the slot")
    void expiryCancelsUnpaidOrder() {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), ALICE);
        Order order = orderService.checkoutDrop(ALICE, res.reservationId());
        setTimes(res.reservationId(), null, LocalDateTime.now().minusMinutes(1));

        assertEquals(1, dropService.expireStaleHolds());

        assertEquals(ReservationStatus.EXPIRED, reservation(res.reservationId()).getStatus());
        assertEquals("CANCELLED", orderRepository.findById(order.getOrderId()).orElseThrow().getStatus());
        assertEquals(0, reservedSlots());
        assertInvariant();
    }

    @Test
    @DisplayName("Abandoned-order cleanup never cuts a live drop hold short")
    void cleanupSkipsOrdersWithLiveHold() {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), ALICE);
        Order order = orderService.checkoutDrop(ALICE, res.reservationId());
        tx.execute(status -> {
            Order o = orderRepository.findById(order.getOrderId()).orElseThrow();
            o.setOrderDate(LocalDateTime.now().minusHours(1));
            orderRepository.save(o);
            return null;
        });

        assertEquals(0, orderService.cancelUnpaidAbandonedOrders(15));
        assertEquals("PLACED", orderRepository.findById(order.getOrderId()).orElseThrow().getStatus());
        assertEquals(1, reservedSlots());
    }

    @Test
    @DisplayName("Paying after the hold lapsed while holding a newer reservation is refunded, not a broken webhook")
    void lateReclaimWithNewerReservationIsRefundCase() {
        ReservationResponseDTO first = dropService.reserve(drop.getId(), ALICE);
        Order order = orderService.checkoutDrop(ALICE, first.reservationId());
        setTimes(first.reservationId(), null, LocalDateTime.now().minusMinutes(1));
        dropService.expireStaleHolds();

        dropService.reserve(drop.getId(), ALICE); // alice grabs a fresh slot

        assertFalse(dropService.confirmByOrderId(order.getOrderId()));
        assertEquals(ReservationStatus.EXPIRED, reservation(first.reservationId()).getStatus());
        assertEquals(1, reservedSlots());
        assertInvariant();
    }

    @Test
    @DisplayName("Late payment after the order was cancelled for a lapsed hold, slot still free: reclaimed and order revived")
    void latePaymentReclaimsSlotAndRevivesOrder() throws Exception {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), ALICE);
        Order order = orderService.checkoutDrop(ALICE, res.reservationId());
        int orderId = order.getOrderId();
        setTimes(res.reservationId(), null, LocalDateTime.now().minusMinutes(1));
        dropService.expireStaleHolds();
        assertEquals("CANCELLED", orderRepository.findById(orderId).orElseThrow().getStatus());
        assertEquals(0, reservedSlots());

        sendWebhook(webhookPayload("evt_late_free_1", "payment_intent.succeeded", orderId, 30.0, "pi_late_free_1"));

        Order after = orderRepository.findById(orderId).orElseThrow();
        assertEquals(PaymentStatus.PAID, after.getPaymentStatus());
        assertEquals("PLACED", after.getStatus(), "the kitchen must see an order that was paid for");
        assertEquals(ReservationStatus.CONFIRMED, reservation(res.reservationId()).getStatus());
        assertEquals(1, reservedSlots());
        assertInvariant();
    }

    // ---------------------------------------------------------------- refunds

    @Test
    @DisplayName("Slot lost after payment: restaurant never sees the order; failed refund is retried until it succeeds")
    void lostSlotOrderIsCancelledAndRefundIsRetried() throws Exception {
        ReservationResponseDTO first = dropService.reserve(drop.getId(), ALICE);
        Order order = orderService.checkoutDrop(ALICE, first.reservationId());
        int orderId = order.getOrderId();
        setTimes(first.reservationId(), null, LocalDateTime.now().minusMinutes(1));
        dropService.expireStaleHolds();
        dropService.reserve(drop.getId(), BOB); // somebody else now owns the only slot

        fakeStripe.setSimulateRefundFailure(true);
        sendWebhook(webhookPayload("evt_lost_1", "payment_intent.succeeded", orderId, 30.0, "pi_lost_1"));

        Order after = orderRepository.findById(orderId).orElseThrow();
        assertEquals("CANCELLED", after.getStatus(), "restaurant must not cook an order whose slot is gone");
        Payment payment = paymentRepository.findByOrder_OrderId(orderId).orElseThrow();
        assertEquals("REFUND_FAILED", payment.getStatus());
        assertEquals(1, payment.getRefundAttempts());
        assertNotNull(payment.getNextRefundAt());

        // not due yet: nothing happens
        assertEquals(0, paymentService.retryFailedRefunds());

        // due, but Stripe still down: attempt counted, still failed
        tx.execute(s -> { Payment p = paymentRepository.findById(payment.getId()).orElseThrow(); p.setNextRefundAt(LocalDateTime.now().minusSeconds(1)); paymentRepository.save(p); return null; });
        assertEquals(0, paymentService.retryFailedRefunds());
        assertEquals(2, paymentRepository.findById(payment.getId()).orElseThrow().getRefundAttempts());

        // Stripe back: retry succeeds
        fakeStripe.setSimulateRefundFailure(false);
        tx.execute(s -> { Payment p = paymentRepository.findById(payment.getId()).orElseThrow(); p.setNextRefundAt(LocalDateTime.now().minusSeconds(1)); paymentRepository.save(p); return null; });
        assertEquals(1, paymentService.retryFailedRefunds());
        assertEquals("REFUNDED", paymentRepository.findById(payment.getId()).orElseThrow().getStatus());
        assertEquals(PaymentStatus.REFUNDED, orderRepository.findById(orderId).orElseThrow().getPaymentStatus());
        assertEquals(1, reservedSlots(), "bob's slot is untouched by alice's refund");
        assertInvariant();
    }

    // --------------------------------------------------------------- waitlist

    @Test
    @DisplayName("Freed slot is handed straight to the oldest waiter; offers cascade when they lapse")
    void slotHandOffIsFifoAndCascades() {
        ReservationResponseDTO alice = dropService.reserve(drop.getId(), ALICE);
        WaitlistEntryResponseDTO bob = dropService.joinWaitlist(drop.getId(), BOB);
        WaitlistEntryResponseDTO carol = dropService.joinWaitlist(drop.getId(), CAROL);
        assertEquals("WAITING", bob.status());
        assertEquals(1, bob.position());
        assertEquals(2, carol.position());

        dropService.release(alice.reservationId(), ALICE);

        // bob now holds the slot; the counter never dipped, so nobody could snipe it
        assertEquals(1, reservedSlots());
        DropReservation bobHold = activeReservationOf(BOB);
        assertEquals(ReservationStatus.HELD, bobHold.getStatus());
        assertTrue(bobHold.getExpiresAt().isBefore(LocalDateTime.now().plusMinutes(5).plusSeconds(5)), "offer window is 5 minutes");
        List<WaitlistEntryResponseDTO> bobMine = dropService.getMyWaitlist(BOB);
        assertEquals("OFFERED", bobMine.get(0).status());
        assertEquals(bobHold.getId(), bobMine.get(0).reservationId());
        assertNotNull(bobMine.get(0).offerExpiresAt());
        assertEquals(1, dropService.getMyWaitlist(CAROL).get(0).position());
        assertInvariant();

        // bob is told his slot is waiting (the notification must really be committed, not just attempted)
        Integer bobUserId = userRepository.findByEmail(BOB).orElseThrow().getUserId();
        assertTrue(notificationRepository.findByUser_UserId(bobUserId).stream()
                .anyMatch(n -> "DROP_SLOT_OFFERED".equals(n.getType()) && n.getMessage().contains("Hold Policy Drop")));

        // an outsider cannot take it
        DropApiException sold = assertThrows(DropApiException.class, () -> dropService.reserve(drop.getId(), "outsider@cravey.com"));
        assertEquals("SOLD_OUT", sold.getCode());

        // bob ignores the offer -> it cascades to carol
        setTimes(bobHold.getId(), null, LocalDateTime.now().minusSeconds(1));
        assertEquals(1, dropService.expireStaleHolds());
        assertEquals(ReservationStatus.EXPIRED, reservation(bobHold.getId()).getStatus());
        assertEquals(ReservationStatus.HELD, activeReservationOf(CAROL).getStatus());
        assertTrue(dropService.getMyWaitlist(BOB).isEmpty(), "bob's entry settled as EXPIRED");
        assertEquals("OFFERED", dropService.getMyWaitlist(CAROL).get(0).status());
        assertEquals(1, reservedSlots());
        assertInvariant();

        // carol's offer lapses with an empty queue -> the slot returns to the pool
        setTimes(activeReservationOf(CAROL).getId(), null, LocalDateTime.now().minusSeconds(1));
        dropService.expireStaleHolds();
        assertEquals(0, reservedSlots());
        assertInvariant();
        assertNotNull(dropService.reserve(drop.getId(), "outsider@cravey.com"));
    }

    @Test
    @DisplayName("Claiming an offer through checkout settles the waitlist entry")
    void offerClaimedByCheckout() {
        ReservationResponseDTO alice = dropService.reserve(drop.getId(), ALICE);
        dropService.joinWaitlist(drop.getId(), BOB);
        dropService.release(alice.reservationId(), ALICE);

        DropReservation bobHold = activeReservationOf(BOB);
        orderService.checkoutDrop(BOB, bobHold.getId());

        assertTrue(dropService.getMyWaitlist(BOB).isEmpty());
        assertEquals(WaitlistStatus.CLAIMED, waitlistRepository.findAll().stream()
                .filter(e -> e.getCustomerEmail().equals(BOB)).findFirst().orElseThrow().getStatus());
        assertInvariant();
    }

    @Test
    @DisplayName("Leaving the waitlist while offered passes the slot to the next person")
    void leavingWhileOfferedPassesSlotOn() {
        ReservationResponseDTO alice = dropService.reserve(drop.getId(), ALICE);
        dropService.joinWaitlist(drop.getId(), BOB);
        dropService.joinWaitlist(drop.getId(), CAROL);
        dropService.release(alice.reservationId(), ALICE);
        assertEquals(ReservationStatus.HELD, activeReservationOf(BOB).getStatus());

        dropService.leaveWaitlist(drop.getId(), BOB);

        assertEquals(ReservationStatus.HELD, activeReservationOf(CAROL).getStatus());
        assertTrue(dropService.getMyWaitlist(BOB).isEmpty());
        assertEquals(1, reservedSlots());
        assertInvariant();
    }

    @Test
    @DisplayName("Joining rules: idempotent, not while slots are free, not while holding, bounded")
    void joinRules() {
        // slots free -> reserve directly
        DropApiException free = assertThrows(DropApiException.class, () -> dropService.joinWaitlist(drop.getId(), BOB));
        assertEquals("SLOTS_AVAILABLE", free.getCode());

        dropService.reserve(drop.getId(), ALICE);
        DropApiException holding = assertThrows(DropApiException.class, () -> dropService.joinWaitlist(drop.getId(), ALICE));
        assertEquals("ALREADY_RESERVED", holding.getCode());

        WaitlistEntryResponseDTO first = dropService.joinWaitlist(drop.getId(), BOB);
        WaitlistEntryResponseDTO again = dropService.joinWaitlist(drop.getId(), BOB);
        assertEquals(first.entryId(), again.entryId());
        assertEquals(1, waitlistRepository.countByDrop_IdAndStatus(drop.getId(), WaitlistStatus.WAITING));

        dropService.setWaitlistMaxPerSlot(1); // 1 slot x 1 = 1 waiter max
        try {
            DropApiException full = assertThrows(DropApiException.class, () -> dropService.joinWaitlist(drop.getId(), CAROL));
            assertEquals("WAITLIST_FULL", full.getCode());
        } finally {
            dropService.setWaitlistMaxPerSlot(5);
        }

        dropService.leaveWaitlist(drop.getId(), BOB);
        assertTrue(dropService.getMyWaitlist(BOB).isEmpty());
        dropService.leaveWaitlist(drop.getId(), BOB); // leaving twice is harmless
    }

    @Test
    @DisplayName("Raised capacity and ended drops are handled by the sweeps")
    void sweepsServeWaitersAndExpireEndedWaitlists() {
        dropService.reserve(drop.getId(), ALICE);
        dropService.joinWaitlist(drop.getId(), BOB);
        dropService.joinWaitlist(drop.getId(), CAROL);

        // organiser adds a slot -> the safety-net sweep offers it to bob
        tx.execute(s -> { Drop d = dropRepository.findById(drop.getId()).orElseThrow(); d.setTotalSlots(2); dropRepository.save(d); return null; });
        assertEquals(1, dropService.promoteWaitlists());
        assertEquals(ReservationStatus.HELD, activeReservationOf(BOB).getStatus());
        assertEquals(2, reservedSlots());
        assertEquals(0, dropService.promoteWaitlists(), "nothing left to do");
        assertInvariant();

        // drop ends -> carol (still WAITING) can never be served
        tx.execute(s -> { Drop d = dropRepository.findById(drop.getId()).orElseThrow(); d.setEndsAt(LocalDateTime.now().minusSeconds(1)); dropRepository.save(d); return null; });
        assertEquals(1, dropService.expireEndedWaitlists());
        assertTrue(dropService.getMyWaitlist(CAROL).isEmpty());
    }

    @Test
    @DisplayName("Raising capacity through updateDrop offers the new slot to the queue")
    void updateDropOffersNewCapacityToQueue() {
        dropService.reserve(drop.getId(), ALICE);
        dropService.joinWaitlist(drop.getId(), BOB);

        dropService.updateDrop(drop.getId(), new com.example.zomato.dto.CreateDropRequestDTO(
                null, null, null, 0, null, null, null, null, 2));

        assertEquals(ReservationStatus.HELD, activeReservationOf(BOB).getStatus());
        assertEquals(2, reservedSlots());
        assertInvariant();

        // and capacity cannot be cut below what is already reserved
        assertThrows(org.springframework.web.server.ResponseStatusException.class, () ->
                dropService.updateDrop(drop.getId(), new com.example.zomato.dto.CreateDropRequestDTO(
                        null, null, null, 0, null, null, null, null, 1)));
    }

    @Test
    @DisplayName("Editing a drop never overwrites live slot accounting with a stale copy")
    void updateDropDoesNotClobberReservedSlots() {
        Drop big = newDrop(5);
        drop = big;
        dropService.reserve(big.getId(), ALICE);
        dropService.updateDrop(big.getId(), new com.example.zomato.dto.CreateDropRequestDTO(
                "Renamed", null, null, 0, null, null, null, null, 0));
        assertEquals(1, reservedSlots());
        assertEquals("Renamed", dropRepository.findById(big.getId()).orElseThrow().getTitle());
    }

    @Test
    @DisplayName("A drop can be deleted once nobody holds it; live holds and paid slots block the delete")
    void deleteDropRules() {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), ALICE);
        DropApiException blocked = assertThrows(DropApiException.class, () -> dropService.deleteDrop(drop.getId()));
        assertEquals("DROP_HAS_RESERVATIONS", blocked.getCode());

        dropService.joinWaitlist(drop.getId(), BOB);
        dropService.release(res.reservationId(), ALICE); // hands the slot to bob
        dropService.leaveWaitlist(drop.getId(), BOB);     // bob gives it up, nothing is held any more
        assertEquals(0, reservedSlots());

        dropService.deleteDrop(drop.getId());
        assertTrue(dropRepository.findById(drop.getId()).isEmpty());
        assertEquals(0, reservationRepository.count());
        assertEquals(0, waitlistRepository.count());
    }

    // ------------------------------------------------------------------- HTTP

    @Test
    @DisplayName("Waitlist endpoints: auth required, join/list/leave round-trip")
    void waitlistEndpoints() throws Exception {
        String aliceAuth = "Bearer " + jwtService.generateToken(ALICE, "CUSTOMER");
        String bobAuth = "Bearer " + jwtService.generateToken(BOB, "CUSTOMER");
        dropService.reserve(drop.getId(), ALICE);

        mockMvc.perform(get("/drops/waitlist/mine")).andExpect(status().isUnauthorized());
        mockMvc.perform(post("/drops/" + drop.getId() + "/waitlist")).andExpect(status().isUnauthorized());

        mockMvc.perform(post("/drops/" + drop.getId() + "/waitlist").header("Authorization", bobAuth))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("WAITING"))
                .andExpect(jsonPath("$.position").value(1))
                .andExpect(jsonPath("$.dropId").value(drop.getId()))
                .andExpect(jsonPath("$.serverTime").isNotEmpty());

        mockMvc.perform(get("/drops/waitlist/mine").header("Authorization", bobAuth))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)));

        mockMvc.perform(post("/drops/" + drop.getId() + "/waitlist").header("Authorization", aliceAuth))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("ALREADY_RESERVED"));

        mockMvc.perform(delete("/drops/" + drop.getId() + "/waitlist").header("Authorization", bobAuth))
                .andExpect(status().isNoContent());
        mockMvc.perform(get("/drops/waitlist/mine").header("Authorization", bobAuth))
                .andExpect(jsonPath("$", hasSize(0)));
    }
}
