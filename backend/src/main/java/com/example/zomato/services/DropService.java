package com.example.zomato.services;

import com.example.zomato.dto.CreateDropRequestDTO;
import com.example.zomato.dto.DropResponseDTO;
import com.example.zomato.dto.ReservationResponseDTO;
import com.example.zomato.entity.*;
import com.example.zomato.exception.DropApiException;
import com.example.zomato.repository.DropRepository;
import com.example.zomato.repository.DropReservationRepository;
import com.example.zomato.repository.RestaurantRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Service
public class DropService {

    private static final Logger log = LoggerFactory.getLogger(DropService.class);
    /** Once an order exists, give the customer longer to finish paying. */
    public static final Duration PAYMENT_WINDOW = Duration.ofMinutes(30);
    public static final Duration HOLD_DURATION = Duration.ofMinutes(10);

    @org.springframework.beans.factory.annotation.Value("${drops.max-per-user:1}")
    private int maxPerUser = 1;

    private final DropRepository drops;
    private final DropReservationRepository reservations;
    private final RestaurantRepository restaurantRepo;
    private final org.springframework.transaction.support.TransactionTemplate transactionTemplate;

    @org.springframework.beans.factory.annotation.Autowired
    public DropService(DropRepository drops,
                       DropReservationRepository reservations,
                       RestaurantRepository restaurantRepo,
                       org.springframework.transaction.PlatformTransactionManager transactionManager) {
        this.drops = drops;
        this.reservations = reservations;
        this.restaurantRepo = restaurantRepo;
        this.transactionTemplate = transactionManager != null ? new org.springframework.transaction.support.TransactionTemplate(transactionManager) : null;
    }

    public DropService(DropRepository drops,
                       DropReservationRepository reservations,
                       RestaurantRepository restaurantRepo) {
        this(drops, reservations, restaurantRepo, (org.springframework.transaction.PlatformTransactionManager) null);
    }

    public DropService(DropRepository drops, DropReservationRepository reservations) {
        this(drops, reservations, null, (org.springframework.transaction.PlatformTransactionManager) null);
    }

    public void setMaxPerUser(int maxPerUser) {
        this.maxPerUser = maxPerUser;
    }

    public record ReserveResult(ReservationResponseDTO reservation, boolean created) {}

    @Transactional(readOnly = true)
    public List<DropResponseDTO> listUpcomingAndLive() {
        LocalDateTime now = LocalDateTime.now();
        List<Drop> dropList = drops.findByEndsAtAfterOrderByStartsAtAsc(now);
        java.util.Map<Integer, String> restaurantNames = new java.util.HashMap<>();
        if (restaurantRepo != null) {
            java.util.Set<Integer> rIds = dropList.stream()
                    .map(Drop::getRestaurantId)
                    .filter(java.util.Objects::nonNull)
                    .collect(java.util.stream.Collectors.toSet());
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

    @Transactional
    public ReservationResponseDTO reserve(int dropId, String email) {
        return reserveWithResult(dropId, email).reservation();
    }

    private final java.util.concurrent.ConcurrentHashMap<String, Object> userDropLocks = new java.util.concurrent.ConcurrentHashMap<>();

    public ReserveResult reserveWithResult(int dropId, String email) {
        String lockKey = dropId + ":" + (email != null ? email.toLowerCase().trim() : "");
        synchronized (userDropLocks.computeIfAbsent(lockKey, k -> new Object())) {
            if (transactionTemplate != null) {
                return transactionTemplate.execute(status -> doReserveInternal(dropId, email));
            } else {
                return doReserveInternal(dropId, email);
            }
        }
    }

    @Transactional
    public ReserveResult doReserveInternal(int dropId, String email) {
        Drop drop = drops.findById(dropId)
                .orElseThrow(() -> new DropApiException(HttpStatus.NOT_FOUND, "DROP_NOT_FOUND", "Drop not found"));

        LocalDateTime now = LocalDateTime.now();

        if (drop.getStartsAt() != null && now.isBefore(drop.getStartsAt())) {
            throw new DropApiException(HttpStatus.CONFLICT, "DROP_NOT_LIVE", "Drop has not started yet");
        }
        if (drop.getEndsAt() != null && now.isAfter(drop.getEndsAt())) {
            throw new DropApiException(HttpStatus.CONFLICT, "DROP_NOT_LIVE", "Drop has already ended");
        }

        // 1. Idempotency & Anti-hoarding check:
        List<DropReservation> active = reservations.findByDrop_IdAndCustomerEmailAndStatusIn(
                dropId, email, List.of(ReservationStatus.HELD, ReservationStatus.CONFIRMED));

        if (!active.isEmpty()) {
            // If already confirmed: strictly 409 ALREADY_RESERVED
            boolean hasConfirmed = active.stream().anyMatch(r -> r.getStatus() == ReservationStatus.CONFIRMED);
            if (hasConfirmed) {
                throw new DropApiException(HttpStatus.CONFLICT, "ALREADY_RESERVED", "You already have a confirmed reservation for this drop");
            }

            // If held and not expired: return existing HELD reservation (200 OK)
            java.util.Optional<DropReservation> unexpiredHeld = active.stream()
                    .filter(r -> r.getStatus() == ReservationStatus.HELD && r.getExpiresAt().isAfter(now))
                    .findFirst();

            if (unexpiredHeld.isPresent()) {
                return new ReserveResult(ReservationResponseDTO.from(unexpiredHeld.get()), false);
            }

            // Stale held reservation: release before creating a new one
            for (DropReservation r : active) {
                if (r.getStatus() == ReservationStatus.HELD && !r.getExpiresAt().isAfter(now)) {
                    transitionAndFreeSlot(r, ReservationStatus.EXPIRED);
                }
            }
        }

        // Per-user limit enforcement
        long activeCount = reservations.countByDrop_IdAndCustomerEmailAndStatusIn(
                dropId, email, List.of(ReservationStatus.HELD, ReservationStatus.CONFIRMED));
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

        // 3. Insert reservation atomically
        DropReservation r = new DropReservation();
        r.setDrop(drop);
        r.setCustomerEmail(email);
        r.setStatus(ReservationStatus.HELD);
        r.setCreatedAt(now);
        r.setExpiresAt(now.plus(HOLD_DURATION));

        try {
            DropReservation saved = reservations.saveAndFlush(r);
            return new ReserveResult(ReservationResponseDTO.from(saved), true);
        } catch (org.springframework.dao.DataIntegrityViolationException ex) {
            // Concurrent request for same user won the race; compensate slot and return existing HELD or throw 409
            drops.releaseSlot(dropId);

            List<DropReservation> winningActive = reservations.findByDrop_IdAndCustomerEmailAndStatusIn(
                    dropId, email, List.of(ReservationStatus.HELD, ReservationStatus.CONFIRMED));
            if (!winningActive.isEmpty()) {
                DropReservation winning = winningActive.get(0);
                if (winning.getStatus() == ReservationStatus.CONFIRMED) {
                    throw new DropApiException(HttpStatus.CONFLICT, "ALREADY_RESERVED", "You already have a confirmed reservation for this drop");
                }
                return new ReserveResult(ReservationResponseDTO.from(winning), false);
            }
            throw new DropApiException(HttpStatus.CONFLICT, "ALREADY_RESERVED", "Reservation conflict");
        }
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
     * 3. A CANCELLED, RELEASED, or EXPIRED reservation occupies 0 slots in d.reservedSlots.
     * 4. 0 <= d.reservedSlots <= d.totalSlots.
     * 5. d.availableSlots == max(0, d.totalSlots - d.reservedSlots).
     *
     * Atomic Transitions & Slot Effects:
     * - [NEW] -> HELD: tryReserveSlot() (+1)
     * - HELD -> CONFIRMED: atomic status transition only (0 net slot change)
     * - HELD -> CANCELLED / EXPIRED: releaseSlot() (-1)
     * - CONFIRMED -> CANCELLED: releaseSlot() (-1)
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
            if (r != null) {
                // Must atomically transition ONLY if still HELD and expiresAt < now
                if (reservations.transitionFromHeldIfExpired(id, ReservationStatus.EXPIRED, now) == 1) {
                    drops.releaseSlot(r.getDrop().getId());
                    freed++;
                }
            }
        }
        return freed;
    }

    /** Checkout: link a held reservation to the order just created and extend the hold. */
    @Transactional
    public void attachOrder(int reservationId, int orderId, String email) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime newExpiresAt = now.plus(PAYMENT_WINDOW);

        int updated = reservations.attachOrderAtomic(reservationId, orderId, email, now, newExpiresAt);
        if (updated == 1) {
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
     * Payment succeeded for this order. Returns true if the order is not a drop order or the slot
     * is confirmed; false if the hold had expired and the slot could not be re-claimed (caller refunds).
     */
    @Transactional
    public boolean confirmByOrderId(int orderId) {
        DropReservation r = reservations.findByOrderId(orderId).orElse(null);
        if (r == null) return true; // normal, non-drop order
        int id = r.getId();
        int dropId = r.getDrop().getId();

        // 1. If currently HELD, atomic transition to CONFIRMED
        if (reservations.transitionFromHeld(id, ReservationStatus.CONFIRMED) == 1) {
            return true;
        }

        // 2. Re-read reservation to check current state
        r = reservations.findById(id).orElseThrow();
        if (r.getStatus() == ReservationStatus.CONFIRMED) {
            return true; // idempotent webhook replay
        }

        // 3. If EXPIRED or CANCELLED, customer paid after hold lapsed.
        // The reclaim path must FIRST win an atomic conditional status transition (EXPIRED/CANCELLED -> CONFIRMED)
        // and ONLY THEN tryReserveSlot, or compensate on failure, so two simultaneous webhooks can never double-increment.
        if (r.getStatus() == ReservationStatus.EXPIRED || r.getStatus() == ReservationStatus.CANCELLED) {
            int won = reservations.transitionFromLapsedToConfirmed(id);
            if (won == 1) {
                // This thread won the status transition! Now try to reserve the slot.
                LocalDateTime now = LocalDateTime.now();
                if (drops.tryReserveSlot(dropId, now) == 1) {
                    return true;
                } else {
                    // No slot available (sold out or drop ended)!
                    // Compensate: rollback status from CONFIRMED back to CANCELLED
                    reservations.transitionStatus(id, ReservationStatus.CONFIRMED, ReservationStatus.CANCELLED);
                    log.error("Order {} paid but drop {} slot was lost; refund required", orderId, dropId);
                    return false;
                }
            } else {
                // Another concurrent webhook already won the status transition.
                DropReservation current = reservations.findById(id).orElse(null);
                if (current != null && current.getStatus() == ReservationStatus.CONFIRMED) {
                    return true; // The winning webhook successfully confirmed
                }
                return false;
            }
        }
        return false;
    }

    /** Order cancelled or refunded: free the slot if it was still held or confirmed. */
    @Transactional
    public void releaseByOrderId(int orderId) {
        reservations.findByOrderId(orderId).ifPresent(r -> {
            int id = r.getId();
            int dropId = r.getDrop().getId();

            // Try atomic CONFIRMED -> CANCELLED transition (decrements slot once)
            if (reservations.transitionFromConfirmedToCancelled(id) == 1) {
                drops.releaseSlot(dropId);
                return;
            }

            // Or try atomic HELD -> CANCELLED transition (decrements slot once)
            if (reservations.transitionFromHeld(id, ReservationStatus.CANCELLED) == 1) {
                drops.releaseSlot(dropId);
            }
            // If already CANCELLED or EXPIRED, do nothing (never double-release).
        });
    }

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
        if (req.totalSlots() > 0) d.setTotalSlots(req.totalSlots());
        Drop saved = drops.save(d);
        String restaurantName = null;
        if (saved.getRestaurantId() != null && restaurantRepo != null) {
            restaurantName = restaurantRepo.findById(saved.getRestaurantId()).map(Restaurant::getName).orElse(null);
        }
        return DropResponseDTO.from(saved, LocalDateTime.now(), restaurantName);
    }

    @Transactional
    public void deleteDrop(int id) {
        if (!drops.existsById(id)) {
            throw new DropApiException(HttpStatus.NOT_FOUND, "DROP_NOT_FOUND", "Drop not found");
        }
        drops.deleteById(id);
    }

    private boolean transitionAndFreeSlot(DropReservation r, ReservationStatus to) {
        int dropId = r.getDrop().getId();
        if (reservations.transitionFromHeld(r.getId(), to) == 0) return false; // already settled
        drops.releaseSlot(dropId);
        return true;
    }
}
