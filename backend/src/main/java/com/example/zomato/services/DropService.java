package com.example.zomato.services;

import com.example.zomato.dto.CreateDropRequestDTO;
import com.example.zomato.dto.DropResponseDTO;
import com.example.zomato.dto.ReservationResponseDTO;
import com.example.zomato.dto.WaitlistEntryResponseDTO;
import com.example.zomato.entity.*;
import com.example.zomato.events.HoldLapsedEvent;
import com.example.zomato.events.WaitlistOfferedEvent;
import com.example.zomato.exception.DropApiException;
import com.example.zomato.repository.DropRepository;
import com.example.zomato.repository.DropReservationRepository;
import com.example.zomato.repository.DropWaitlistRepository;
import com.example.zomato.repository.RestaurantRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.server.ResponseStatusException;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Limited-quantity drops: atomic slot holds, payment-aware expiry and a FIFO waitlist.
 *
 * <h3>One timer rule (all values configurable under {@code drops.*})</h3>
 * <ul>
 *   <li>Reserve: the slot is HELD for {@code hold-minutes} (default 10).</li>
 *   <li>Checkout started ({@link #attachOrder}): at least {@code min-payment-minutes} (default 5) remain.</li>
 *   <li>Payment in flight (intent created, Stripe {@code processing} / {@code requires_action}):
 *       extended to {@code now + payment-grace-minutes} (default 5), see {@link #extendHoldForPayment}.</li>
 *   <li>No extension ever pushes a hold past {@code createdAt + hard-cap-minutes} (default 20).</li>
 *   <li>A waitlist offer is a HELD reservation that lasts {@code offer-minutes} (default 5).</li>
 * </ul>
 */
@Service
public class DropService {

    private static final Logger log = LoggerFactory.getLogger(DropService.class);

    private static final List<ReservationStatus> ACTIVE = List.of(ReservationStatus.HELD, ReservationStatus.CONFIRMED);
    private static final List<WaitlistStatus> LIVE_WAITLIST = List.of(WaitlistStatus.WAITING, WaitlistStatus.OFFERED);

    @Value("${drops.max-per-user:1}")
    private int maxPerUser = 1;
    @Value("${drops.hold-minutes:10}")
    private long holdMinutes = 10;
    @Value("${drops.min-payment-minutes:5}")
    private long minPaymentMinutes = 5;
    @Value("${drops.payment-grace-minutes:5}")
    private long paymentGraceMinutes = 5;
    @Value("${drops.hard-cap-minutes:20}")
    private long hardCapMinutes = 20;
    @Value("${drops.offer-minutes:5}")
    private long offerMinutes = 5;
    @Value("${drops.waitlist-max-per-slot:5}")
    private int waitlistMaxPerSlot = 5;

    private final DropRepository drops;
    private final DropReservationRepository reservations;
    private final DropWaitlistRepository waitlist;
    private final RestaurantRepository restaurantRepo;
    private final TransactionTemplate transactionTemplate;
    private ApplicationEventPublisher events;

    @Autowired
    public DropService(DropRepository drops,
                       DropReservationRepository reservations,
                       DropWaitlistRepository waitlist,
                       RestaurantRepository restaurantRepo,
                       PlatformTransactionManager transactionManager) {
        this.drops = drops;
        this.reservations = reservations;
        this.waitlist = waitlist;
        this.restaurantRepo = restaurantRepo;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
    }

    @Autowired(required = false)
    public void setEvents(ApplicationEventPublisher events) {
        this.events = events;
    }

    public void setMaxPerUser(int maxPerUser) {
        this.maxPerUser = maxPerUser;
    }

    public void setHoldMinutes(long holdMinutes) { this.holdMinutes = holdMinutes; }
    public void setMinPaymentMinutes(long minPaymentMinutes) { this.minPaymentMinutes = minPaymentMinutes; }
    public void setPaymentGraceMinutes(long paymentGraceMinutes) { this.paymentGraceMinutes = paymentGraceMinutes; }
    public void setHardCapMinutes(long hardCapMinutes) { this.hardCapMinutes = hardCapMinutes; }
    public void setOfferMinutes(long offerMinutes) { this.offerMinutes = offerMinutes; }
    public void setWaitlistMaxPerSlot(int waitlistMaxPerSlot) { this.waitlistMaxPerSlot = waitlistMaxPerSlot; }

    public Duration holdDuration() { return Duration.ofMinutes(holdMinutes); }
    public Duration hardCap() { return Duration.ofMinutes(hardCapMinutes); }

    public record ReserveResult(ReservationResponseDTO reservation, boolean created) {}

    // ------------------------------------------------------------------ reads

    @Transactional(readOnly = true)
    public List<DropResponseDTO> listUpcomingAndLive() {
        LocalDateTime now = LocalDateTime.now();
        List<Drop> dropList = drops.findByEndsAtAfterOrderByStartsAtAsc(now);
        Map<Integer, String> restaurantNames = new HashMap<>();
        if (restaurantRepo != null) {
            Set<Integer> rIds = dropList.stream()
                    .map(Drop::getRestaurantId)
                    .filter(Objects::nonNull)
                    .collect(Collectors.toSet());
            if (!rIds.isEmpty()) {
                restaurantRepo.findAllById(rIds).forEach(r -> restaurantNames.put(r.getId(), r.getName()));
            }
        }
        return dropList.stream()
                .map(d -> DropResponseDTO.from(d, now, restaurantNames.get(d.getRestaurantId())))
                .toList();
    }

    @Transactional(readOnly = true)
    public DropResponseDTO get(int id) {
        Drop d = drops.findById(id).orElseThrow(() -> new DropApiException(HttpStatus.NOT_FOUND, "DROP_NOT_FOUND", "Drop not found"));
        String restaurantName = null;
        if (d.getRestaurantId() != null && restaurantRepo != null) {
            restaurantName = restaurantRepo.findById(d.getRestaurantId()).map(Restaurant::getName).orElse(null);
        }
        return DropResponseDTO.from(d, LocalDateTime.now(), restaurantName);
    }

    @Transactional(readOnly = true)
    public List<ReservationResponseDTO> getMyActiveReservations(String email) {
        LocalDateTime now = LocalDateTime.now();
        return reservations.findActiveByCustomerEmail(email, now).stream()
                .map(ReservationResponseDTO::from)
                .toList();
    }

    // ---------------------------------------------------------------- reserve

    public ReservationResponseDTO reserve(int dropId, String email) {
        return reserveWithResult(dropId, email).reservation();
    }

    private final ConcurrentHashMap<String, Object> userDropLocks = new ConcurrentHashMap<>();

    /**
     * The per-(drop,user) JVM lock only avoids pointless contention inside one instance. Correctness across
     * instances comes from the partial unique index: the losing transaction fails as a whole (including its
     * slot increment), then resolves to the winner's reservation in a fresh transaction.
     */
    public ReserveResult reserveWithResult(int dropId, String email) {
        String lockKey = dropId + ":" + (email != null ? email.toLowerCase().trim() : "");
        synchronized (userDropLocks.computeIfAbsent(lockKey, k -> new Object())) {
            try {
                return transactionTemplate.execute(status -> doReserve(dropId, email));
            } catch (DataIntegrityViolationException ex) {
                return transactionTemplate.execute(status -> resolveConcurrentReserve(dropId, email));
            }
        }
    }

    private ReserveResult doReserve(int dropId, String email) {
        Drop drop = drops.findById(dropId)
                .orElseThrow(() -> new DropApiException(HttpStatus.NOT_FOUND, "DROP_NOT_FOUND", "Drop not found"));

        LocalDateTime now = LocalDateTime.now();

        if (drop.getStartsAt() != null && now.isBefore(drop.getStartsAt())) {
            throw new DropApiException(HttpStatus.CONFLICT, "DROP_NOT_LIVE", "Drop has not started yet");
        }
        if (drop.getEndsAt() != null && now.isAfter(drop.getEndsAt())) {
            throw new DropApiException(HttpStatus.CONFLICT, "DROP_NOT_LIVE", "Drop has already ended");
        }

        // 1. Idempotency & anti-hoarding
        List<DropReservation> active = reservations.findByDrop_IdAndCustomerEmailAndStatusIn(dropId, email, ACTIVE);
        if (!active.isEmpty()) {
            if (active.stream().anyMatch(r -> r.getStatus() == ReservationStatus.CONFIRMED)) {
                throw new DropApiException(HttpStatus.CONFLICT, "ALREADY_RESERVED", "You already have a confirmed reservation for this drop");
            }

            Optional<DropReservation> unexpiredHeld = active.stream()
                    .filter(r -> r.getStatus() == ReservationStatus.HELD && r.getExpiresAt().isAfter(now))
                    .findFirst();
            if (unexpiredHeld.isPresent()) {
                return new ReserveResult(ReservationResponseDTO.from(unexpiredHeld.get()), false);
            }

            // Stale hold: settle it before creating a new one
            for (DropReservation r : active) {
                if (r.getStatus() == ReservationStatus.HELD && !r.getExpiresAt().isAfter(now)) {
                    transitionAndFreeSlot(r, ReservationStatus.EXPIRED);
                }
            }
        }

        long activeCount = reservations.countByDrop_IdAndCustomerEmailAndStatusIn(dropId, email, ACTIVE);
        if (activeCount >= maxPerUser) {
            throw new DropApiException(HttpStatus.CONFLICT, "ALREADY_RESERVED", "Maximum reservation limit reached for this drop");
        }

        // 2. The single atomic check-and-increment. No read-then-write race.
        if (drops.tryReserveSlot(dropId, now) == 0) {
            Drop current = drops.findById(dropId).orElse(drop);
            if (current.getStartsAt() != null && (now.isBefore(current.getStartsAt()) || now.isAfter(current.getEndsAt()))) {
                throw new DropApiException(HttpStatus.CONFLICT, "DROP_NOT_LIVE", "Drop is not live");
            }
            throw new DropApiException(HttpStatus.CONFLICT, "SOLD_OUT", "Drop is sold out");
        }

        // 3. Insert the reservation. A unique-index violation propagates and rolls back step 2 with it.
        DropReservation r = new DropReservation();
        r.setDrop(drops.getReferenceById(dropId));
        r.setCustomerEmail(email);
        r.setStatus(ReservationStatus.HELD);
        r.setCreatedAt(now);
        r.setExpiresAt(now.plus(holdDuration()));
        DropReservation saved = reservations.saveAndFlush(r);
        return new ReserveResult(ReservationResponseDTO.from(saved), true);
    }

    private ReserveResult resolveConcurrentReserve(int dropId, String email) {
        List<DropReservation> winning = reservations.findByDrop_IdAndCustomerEmailAndStatusIn(dropId, email, ACTIVE);
        if (!winning.isEmpty()) {
            DropReservation w = winning.get(0);
            if (w.getStatus() == ReservationStatus.CONFIRMED) {
                throw new DropApiException(HttpStatus.CONFLICT, "ALREADY_RESERVED", "You already have a confirmed reservation for this drop");
            }
            return new ReserveResult(ReservationResponseDTO.from(w), false);
        }
        throw new DropApiException(HttpStatus.CONFLICT, "ALREADY_RESERVED", "Reservation conflict");
    }

    /**
     * =========================================================================
     * SLOT ACCOUNTING INVARIANT:
     * For every drop d:
     *   d.reservedSlots == count(r in d.reservations WHERE r.status IN (HELD, CONFIRMED))
     *
     * Invariant Properties:
     * 1. A HELD reservation occupies exactly 1 slot in d.reservedSlots.
     * 2. A CONFIRMED reservation occupies exactly 1 slot in d.reservedSlots.
     * 3. A CANCELLED or EXPIRED reservation occupies 0 slots in d.reservedSlots.
     * 4. 0 <= d.reservedSlots <= d.totalSlots.
     * 5. d.availableSlots == max(0, d.totalSlots - d.reservedSlots).
     *
     * Atomic Transitions & Slot Effects:
     * - [NEW] -> HELD: tryReserveSlot() (+1)
     * - HELD -> CONFIRMED: atomic status transition only (0 net slot change)
     * - HELD / CONFIRMED -> CANCELLED / EXPIRED: freeOrHandOff():
     *     * nobody waiting: releaseSlot() (-1)
     *     * somebody waiting: the slot is handed straight to the oldest WAITING entry as a new HELD
     *       reservation (0 net slot change, so nobody can snipe it in between)
     * - EXPIRED/CANCELLED -> CONFIRMED (late-payment reclaim):
     *     first win transitionFromLapsedToConfirmed(), then tryReserveSlot() (+1).
     *     On failure, rollback status CONFIRMED -> CANCELLED (0 net slot change).
     * =========================================================================
     */

    /** User cancels their own hold. */
    @Transactional
    public void release(int reservationId, String email) {
        DropReservation r = reservations.findById(reservationId)
                .orElseThrow(() -> new DropApiException(HttpStatus.NOT_FOUND, "RESERVATION_NOT_FOUND", "Reservation not found"));
        if (!r.getCustomerEmail().equalsIgnoreCase(email)) {
            throw new DropApiException(HttpStatus.FORBIDDEN, "NOT_YOUR_RESERVATION", "Not your reservation");
        }
        if (r.getStatus() != ReservationStatus.HELD) {
            if (r.getStatus() == ReservationStatus.CONFIRMED) {
                throw new DropApiException(HttpStatus.CONFLICT, "RESERVATION_ALREADY_USED", "Reservation is already confirmed");
            }
            if (r.getStatus() == ReservationStatus.EXPIRED) {
                throw new DropApiException(HttpStatus.CONFLICT, "HOLD_EXPIRED", "Reservation hold has expired");
            }
            throw new DropApiException(HttpStatus.CONFLICT, "HOLD_EXPIRED", "Reservation is not currently held");
        }
        if (r.getExpiresAt().isBefore(LocalDateTime.now())) {
            transitionAndFreeSlot(r, ReservationStatus.EXPIRED);
            throw new DropApiException(HttpStatus.CONFLICT, "HOLD_EXPIRED", "Reservation hold has expired");
        }
        transitionAndFreeSlot(r, ReservationStatus.CANCELLED);
    }

    /** Call from the payment-success path (PaymentService) once the order is paid. */
    @Transactional
    public void confirm(int reservationId, int orderId) {
        if (reservations.transitionFromHeld(reservationId, ReservationStatus.CONFIRMED) == 0) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Reservation is no longer held");
        }
        // transitionFromHeld cleared the persistence context, so reload before setting orderId
        DropReservation r = reservations.findById(reservationId).orElseThrow();
        r.setOrderId(orderId);
        reservations.save(r);
    }

    /** Call from the payment-failed path. */
    @Transactional
    public void releaseByPaymentFailure(int reservationId) {
        reservations.findById(reservationId)
                .ifPresent(r -> transitionAndFreeSlot(r, ReservationStatus.CANCELLED));
    }

    @Transactional
    public int expireStaleHolds() {
        LocalDateTime now = LocalDateTime.now();
        List<Integer> ids = reservations.findStaleHeldIds(now);
        int freed = 0;
        for (int id : ids) {
            DropReservation r = reservations.findById(id).orElse(null);
            if (r != null && transitionAndFreeSlot(r, ReservationStatus.EXPIRED, true)) {
                freed++;
            }
        }
        return freed;
    }

    // ---------------------------------------------------------- checkout/pay

    /**
     * Checkout: link a held reservation to the order just created. Guarantees the customer at least
     * {@code min-payment-minutes} to pay (never shortens an existing, longer hold) without exceeding the hard cap.
     */
    @Transactional
    public void attachOrder(int reservationId, int orderId, String email) {
        LocalDateTime now = LocalDateTime.now();
        DropReservation current = reservations.findById(reservationId)
                .orElseThrow(() -> new DropApiException(HttpStatus.NOT_FOUND, "RESERVATION_NOT_FOUND", "Reservation not found"));

        LocalDateTime newExpiresAt = capped(current, now.plus(Duration.ofMinutes(minPaymentMinutes)));

        int updated = reservations.attachOrderAtomic(reservationId, orderId, email, now, newExpiresAt);
        if (updated == 1) {
            if (waitlist != null) {
                waitlist.transitionByReservation(reservationId, WaitlistStatus.OFFERED, WaitlistStatus.CLAIMED);
            }
            return;
        }

        // Row was not updated. Inspect current state to throw precise error code
        DropReservation r = reservations.findById(reservationId)
                .orElseThrow(() -> new DropApiException(HttpStatus.NOT_FOUND, "RESERVATION_NOT_FOUND", "Reservation not found"));

        if (!r.getCustomerEmail().equalsIgnoreCase(email)) {
            throw new DropApiException(HttpStatus.FORBIDDEN, "NOT_YOUR_RESERVATION", "Not your reservation");
        }
        if (r.getStatus() != ReservationStatus.HELD || r.getExpiresAt().isBefore(now) || r.getOrderId() != null) {
            if (r.getStatus() == ReservationStatus.CONFIRMED || r.getOrderId() != null) {
                throw new DropApiException(HttpStatus.CONFLICT, "RESERVATION_ALREADY_USED", "Reservation already used or confirmed");
            }
            throw new DropApiException(HttpStatus.CONFLICT, "HOLD_EXPIRED", "Reservation expired");
        }
        throw new DropApiException(HttpStatus.CONFLICT, "HOLD_EXPIRED", "Could not attach order to reservation");
    }

    /**
     * A payment for this order is in flight (intent created, 3-D Secure, or Stripe is processing it).
     * Pushes the hold to {@code now + payment-grace-minutes}, never past the hard cap and never backwards.
     *
     * @return true if the expiry moved forward
     */
    @Transactional
    public boolean extendHoldForPayment(int orderId) {
        DropReservation r = reservations.findByOrderId(orderId).orElse(null);
        if (r == null || r.getStatus() != ReservationStatus.HELD) return false;
        LocalDateTime target = capped(r, LocalDateTime.now().plus(Duration.ofMinutes(paymentGraceMinutes)));
        return reservations.extendExpiry(r.getId(), target) == 1;
    }

    private LocalDateTime capped(DropReservation r, LocalDateTime proposed) {
        LocalDateTime cap = r.getCreatedAt().plus(hardCap());
        return proposed.isAfter(cap) ? cap : proposed;
    }

    /**
     * Payment succeeded for this order. Returns true if the order is not a drop order or the slot
     * is confirmed; false if the hold had expired and the slot could not be re-claimed (caller refunds).
     */
    @Transactional
    public boolean confirmByOrderId(int orderId) {
        DropReservation r = reservations.findByOrderId(orderId).orElse(null);
        if (r == null) return true; // normal, non-drop order
        int id = r.getId();
        int dropId = r.getDrop().getId();
        String email = r.getCustomerEmail();

        // 1. If currently HELD, atomic transition to CONFIRMED
        if (reservations.transitionFromHeld(id, ReservationStatus.CONFIRMED) == 1) {
            return true;
        }

        // 2. Re-read reservation to check current state
        r = reservations.findById(id).orElseThrow();
        if (r.getStatus() == ReservationStatus.CONFIRMED) {
            return true; // idempotent webhook replay
        }

        // 3. EXPIRED or CANCELLED: the customer paid after the hold lapsed.
        // The reclaim path must FIRST win an atomic conditional status transition (EXPIRED/CANCELLED -> CONFIRMED)
        // and ONLY THEN tryReserveSlot, or compensate on failure, so two simultaneous webhooks can never double-increment.
        if (r.getStatus() == ReservationStatus.EXPIRED || r.getStatus() == ReservationStatus.CANCELLED) {
            // The customer may have re-reserved after the lapse. A second active row would violate the
            // one-active-per-user index and break the whole webhook, so treat it as "slot lost" (refund).
            final int lapsedId = id;
            boolean hasNewerActive = reservations.findByDrop_IdAndCustomerEmailAndStatusIn(dropId, email, ACTIVE)
                    .stream().anyMatch(other -> other.getId() != lapsedId);
            if (hasNewerActive) {
                log.warn("Order {} paid after hold lapsed but customer holds a newer reservation on drop {}; refund required", orderId, dropId);
                return false;
            }
            int won = reservations.transitionFromLapsedToConfirmed(id);
            if (won == 1) {
                LocalDateTime now = LocalDateTime.now();
                if (drops.tryReserveSlot(dropId, now) == 1) {
                    return true;
                } else {
                    // No slot available (sold out or drop ended): compensate by rolling the status back
                    reservations.transitionStatus(id, ReservationStatus.CONFIRMED, ReservationStatus.CANCELLED);
                    log.error("Order {} paid but drop {} slot was lost; refund required", orderId, dropId);
                    return false;
                }
            } else {
                // Another concurrent webhook already won the status transition.
                DropReservation current = reservations.findById(id).orElse(null);
                return current != null && current.getStatus() == ReservationStatus.CONFIRMED;
            }
        }
        return false;
    }

    /** True if this order was created from a drop reservation. */
    @Transactional(readOnly = true)
    public boolean isDropOrder(int orderId) {
        return reservations.findByOrderId(orderId).isPresent();
    }

    /** Order cancelled or refunded: free the slot if it was still held or confirmed. */
    @Transactional
    public void releaseByOrderId(int orderId) {
        reservations.findByOrderId(orderId).ifPresent(r -> {
            int id = r.getId();
            int dropId = r.getDrop().getId();

            // Try atomic CONFIRMED -> CANCELLED transition (frees the slot once)
            if (reservations.transitionFromConfirmedToCancelled(id) == 1) {
                freeOrHandOff(dropId);
                return;
            }

            // Or try atomic HELD -> CANCELLED transition (frees the slot once)
            if (reservations.transitionFromHeld(id, ReservationStatus.CANCELLED) == 1) {
                if (waitlist != null) {
                    waitlist.transitionByReservation(id, WaitlistStatus.OFFERED, WaitlistStatus.LEFT);
                }
                freeOrHandOff(dropId);
            }
            // If already CANCELLED or EXPIRED, do nothing (never double-release).
        });
    }

    private boolean transitionAndFreeSlot(DropReservation r, ReservationStatus to) {
        return transitionAndFreeSlot(r, to, false);
    }

    /**
     * Atomically settles a HELD reservation and frees its slot exactly once.
     *
     * @param onlyIfExpired when true the transition only wins if the hold is still past its expiry, so a
     *                      payment-aware extension that landed first is never overridden
     */
    private boolean transitionAndFreeSlot(DropReservation r, ReservationStatus to, boolean onlyIfExpired) {
        int dropId = r.getDrop().getId();
        int won = onlyIfExpired
                ? reservations.transitionFromHeldIfExpired(r.getId(), to, LocalDateTime.now())
                : reservations.transitionFromHeld(r.getId(), to);
        if (won == 0) return false; // already settled (or extended)

        if (waitlist != null) {
            waitlist.transitionByReservation(r.getId(), WaitlistStatus.OFFERED,
                    to == ReservationStatus.EXPIRED ? WaitlistStatus.EXPIRED : WaitlistStatus.LEFT);
        }
        if (r.getOrderId() != null && events != null) {
            events.publishEvent(new HoldLapsedEvent(r.getId(), r.getOrderId()));
        }
        freeOrHandOff(dropId);
        return true;
    }

    // --------------------------------------------------------------- waitlist

    /** Frees one slot: hands it to the oldest waiter if there is one, otherwise returns it to the pool. */
    private void freeOrHandOff(int dropId) {
        if (!offerNextWaiter(dropId, true)) {
            drops.releaseSlot(dropId);
        }
    }

    /**
     * Creates a HELD reservation (offer window) for the oldest WAITING entry, reusing a slot that is already
     * counted in {@code reservedSlots}. Returns false if there is nobody to offer to.
     */
    private boolean offerNextWaiter(int dropId, boolean checkDropLive) {
        if (waitlist == null) return false;
        LocalDateTime now = LocalDateTime.now();
        Drop drop = drops.findById(dropId).orElse(null);
        if (drop == null) return false;
        if (checkDropLive && drop.getEndsAt() != null && !now.isBefore(drop.getEndsAt())) return false;
        String title = drop.getTitle();

        while (true) {
            DropWaitlistEntry next = waitlist.findFirstByDrop_IdAndStatusOrderByIdAsc(dropId, WaitlistStatus.WAITING).orElse(null);
            if (next == null) return false;
            int entryId = next.getId();
            String email = next.getCustomerEmail();

            if (waitlist.transition(entryId, WaitlistStatus.WAITING, WaitlistStatus.OFFERED) == 0) {
                continue; // another transaction took this entry, try the next one
            }
            if (reservations.countByDrop_IdAndCustomerEmailAndStatusIn(dropId, email, ACTIVE) > 0) {
                waitlist.transition(entryId, WaitlistStatus.OFFERED, WaitlistStatus.LEFT); // already holds a slot
                continue;
            }

            DropReservation r = new DropReservation();
            r.setDrop(drops.getReferenceById(dropId));
            r.setCustomerEmail(email);
            r.setStatus(ReservationStatus.HELD);
            r.setCreatedAt(now);
            r.setExpiresAt(now.plus(Duration.ofMinutes(offerMinutes)));
            DropReservation saved = reservations.saveAndFlush(r);
            waitlist.markOffered(entryId, saved.getId(), now);

            if (events != null) {
                events.publishEvent(new WaitlistOfferedEvent(email, dropId, title, saved.getId(), saved.getExpiresAt()));
            }
            return true;
        }
    }

    /** Offers every free slot of a live drop to its waiters, oldest first. */
    private void fillFromWaitlist(int dropId) {
        while (drops.tryReserveSlot(dropId, LocalDateTime.now()) == 1) {
            if (!offerNextWaiter(dropId, false)) {
                drops.releaseSlot(dropId);
                return;
            }
        }
    }

    /** Scheduler safety net: serves waiters of drops that have a free slot (missed hand-off, raised capacity). */
    @Transactional
    public int promoteWaitlists() {
        if (waitlist == null) return 0;
        List<Integer> dropIds = waitlist.findDropIdsWithWaitersAndFreeSlots(LocalDateTime.now());
        dropIds.forEach(this::fillFromWaitlist);
        return dropIds.size();
    }

    /** Nobody WAITING on a drop that has ended can ever be served. */
    @Transactional
    public int expireEndedWaitlists() {
        return waitlist == null ? 0 : waitlist.expireForEndedDrops(LocalDateTime.now());
    }

    public WaitlistEntryResponseDTO joinWaitlist(int dropId, String email) {
        String lockKey = dropId + ":" + (email != null ? email.toLowerCase().trim() : "");
        synchronized (userDropLocks.computeIfAbsent(lockKey, k -> new Object())) {
            try {
                return transactionTemplate.execute(status -> doJoinWaitlist(dropId, email));
            } catch (DataIntegrityViolationException ex) {
                return transactionTemplate.execute(status -> {
                    List<DropWaitlistEntry> existing = waitlist.findActiveForUser(dropId, email, LIVE_WAITLIST);
                    if (existing.isEmpty()) {
                        throw new DropApiException(HttpStatus.CONFLICT, "ALREADY_ON_WAITLIST", "Waitlist conflict");
                    }
                    return toDto(existing.get(0));
                });
            }
        }
    }

    private WaitlistEntryResponseDTO doJoinWaitlist(int dropId, String email) {
        Drop drop = drops.findById(dropId)
                .orElseThrow(() -> new DropApiException(HttpStatus.NOT_FOUND, "DROP_NOT_FOUND", "Drop not found"));
        LocalDateTime now = LocalDateTime.now();
        if (drop.getStartsAt() != null && now.isBefore(drop.getStartsAt())) {
            throw new DropApiException(HttpStatus.CONFLICT, "DROP_NOT_LIVE", "Drop has not started yet");
        }
        if (drop.getEndsAt() != null && !now.isBefore(drop.getEndsAt())) {
            throw new DropApiException(HttpStatus.CONFLICT, "DROP_NOT_LIVE", "Drop has already ended");
        }

        List<DropWaitlistEntry> existing = waitlist.findActiveForUser(dropId, email, LIVE_WAITLIST);
        if (!existing.isEmpty()) {
            return toDto(existing.get(0)); // idempotent
        }
        if (reservations.countByDrop_IdAndCustomerEmailAndStatusIn(dropId, email, ACTIVE) > 0) {
            throw new DropApiException(HttpStatus.CONFLICT, "ALREADY_RESERVED", "You already hold a slot for this drop");
        }
        if (drop.getReservedSlots() < drop.getTotalSlots()) {
            throw new DropApiException(HttpStatus.CONFLICT, "SLOTS_AVAILABLE", "Slots are still available - reserve directly");
        }
        long waiting = waitlist.countByDrop_IdAndStatus(dropId, WaitlistStatus.WAITING);
        if (waiting >= (long) drop.getTotalSlots() * waitlistMaxPerSlot) {
            throw new DropApiException(HttpStatus.CONFLICT, "WAITLIST_FULL", "The waitlist for this drop is full");
        }

        DropWaitlistEntry entry = new DropWaitlistEntry();
        entry.setDrop(drop);
        entry.setCustomerEmail(email);
        entry.setStatus(WaitlistStatus.WAITING);
        entry.setCreatedAt(now);
        DropWaitlistEntry saved = waitlist.saveAndFlush(entry);

        // A slot may have been freed between the check above and the insert becoming visible; serve it now
        // (the scheduler sweep covers the remaining sub-millisecond interleavings).
        if (drops.findById(dropId).map(d -> d.getReservedSlots() < d.getTotalSlots()).orElse(false)) {
            fillFromWaitlist(dropId);
            saved = waitlist.findById(saved.getId()).orElse(saved);
        }
        return toDto(saved);
    }

    @Transactional
    public void leaveWaitlist(int dropId, String email) {
        for (DropWaitlistEntry e : waitlist.findActiveForUser(dropId, email, LIVE_WAITLIST)) {
            if (e.getStatus() == WaitlistStatus.WAITING) {
                waitlist.transition(e.getId(), WaitlistStatus.WAITING, WaitlistStatus.LEFT);
            } else if (e.getReservationId() != null) {
                // Offered: give the held slot back so it moves on to the next person in line.
                reservations.findById(e.getReservationId()).ifPresent(r -> transitionAndFreeSlot(r, ReservationStatus.CANCELLED));
            }
        }
    }

    @Transactional(readOnly = true)
    public List<WaitlistEntryResponseDTO> getMyWaitlist(String email) {
        return waitlist.findAllActiveForUser(email, LIVE_WAITLIST).stream().map(this::toDto).toList();
    }

    private WaitlistEntryResponseDTO toDto(DropWaitlistEntry e) {
        int dropId = e.getDrop().getId();
        if (e.getStatus() == WaitlistStatus.WAITING) {
            int position = (int) waitlist.countByDrop_IdAndStatusAndIdLessThan(dropId, WaitlistStatus.WAITING, e.getId()) + 1;
            return WaitlistEntryResponseDTO.from(e, position, null);
        }
        LocalDateTime offerExpiresAt = e.getReservationId() == null ? null
                : reservations.findById(e.getReservationId()).map(DropReservation::getExpiresAt).orElse(null);
        return WaitlistEntryResponseDTO.from(e, 0, offerExpiresAt);
    }

    // ------------------------------------------------------------- admin CRUD

    @Transactional
    public DropResponseDTO createDrop(CreateDropRequestDTO req) {
        if (req.restaurantId() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Restaurant ID is required");
        }
        if (restaurantRepo != null && !restaurantRepo.existsById(req.restaurantId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Restaurant not found with id: " + req.restaurantId());
        }
        Drop d = new Drop();
        d.setTitle(req.title());
        d.setDescription(req.description());
        d.setImageUrl(req.imageUrl());
        d.setPrice(req.price());
        d.setRestaurantId(req.restaurantId());
        d.setMenuItemId(req.menuItemId());
        d.setStartsAt(req.startsAt() != null ? req.startsAt() : LocalDateTime.now());
        d.setEndsAt(req.endsAt() != null ? req.endsAt() : LocalDateTime.now().plusHours(2));
        d.setTotalSlots(req.totalSlots());
        d.setReservedSlots(0);
        Drop saved = drops.save(d);
        String restaurantName = null;
        if (saved.getRestaurantId() != null && restaurantRepo != null) {
            restaurantName = restaurantRepo.findById(saved.getRestaurantId()).map(Restaurant::getName).orElse(null);
        }
        return DropResponseDTO.from(saved, LocalDateTime.now(), restaurantName);
    }

    @Transactional
    public DropResponseDTO updateDrop(int id, CreateDropRequestDTO req) {
        Drop d = drops.findById(id).orElseThrow(() -> new DropApiException(HttpStatus.NOT_FOUND, "DROP_NOT_FOUND", "Drop not found"));
        if (req.title() != null) d.setTitle(req.title());
        if (req.description() != null) d.setDescription(req.description());
        if (req.imageUrl() != null) d.setImageUrl(req.imageUrl());
        if (req.price() > 0) d.setPrice(req.price());
        if (req.restaurantId() != null) {
            if (restaurantRepo != null && !restaurantRepo.existsById(req.restaurantId())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Restaurant not found with id: " + req.restaurantId());
            }
            d.setRestaurantId(req.restaurantId());
        }
        if (req.menuItemId() != null) d.setMenuItemId(req.menuItemId());
        if (req.startsAt() != null) d.setStartsAt(req.startsAt());
        if (req.endsAt() != null) d.setEndsAt(req.endsAt());
        boolean capacityRaised = false;
        if (req.totalSlots() > 0) {
            if (req.totalSlots() < d.getReservedSlots()) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                        "Cannot reduce totalSlots below the " + d.getReservedSlots() + " slots already reserved");
            }
            capacityRaised = req.totalSlots() > d.getTotalSlots();
            d.setTotalSlots(req.totalSlots());
        }
        Drop saved = drops.saveAndFlush(d);
        if (capacityRaised) {
            fillFromWaitlist(saved.getId());
        }
        String restaurantName = null;
        if (saved.getRestaurantId() != null && restaurantRepo != null) {
            restaurantName = restaurantRepo.findById(saved.getRestaurantId()).map(Restaurant::getName).orElse(null);
        }
        return DropResponseDTO.from(drops.findById(saved.getId()).orElse(saved), LocalDateTime.now(), restaurantName);
    }

    /**
     * Deletes a drop that nobody is currently holding or has paid for. Settled history (cancelled / expired
     * reservations, closed waitlist entries) goes with it; live holds and confirmed slots block the delete so a
     * paid customer is never left with an order for a drop that no longer exists.
     */
    @Transactional
    public void deleteDrop(int id) {
        if (!drops.existsById(id)) {
            throw new DropApiException(HttpStatus.NOT_FOUND, "DROP_NOT_FOUND", "Drop not found");
        }
        if (reservations.countByDrop_IdAndStatusIn(id, ACTIVE) > 0) {
            throw new DropApiException(HttpStatus.CONFLICT, "DROP_HAS_RESERVATIONS",
                    "Drop has held or confirmed reservations; cancel them first");
        }
        waitlist.deleteByDrop_Id(id);
        reservations.deleteByDrop_Id(id);
        drops.deleteById(id);
    }
}
