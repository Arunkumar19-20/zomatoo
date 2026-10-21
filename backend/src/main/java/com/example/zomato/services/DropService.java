package com.example.zomato.services;

import com.example.zomato.dto.CreateDropRequestDTO;
import com.example.zomato.dto.DropResponseDTO;
import com.example.zomato.dto.ReservationResponseDTO;
import com.example.zomato.entity.*;
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

    private final DropRepository drops;
    private final DropReservationRepository reservations;
    private final RestaurantRepository restaurantRepo;

    @org.springframework.beans.factory.annotation.Autowired
    public DropService(DropRepository drops, DropReservationRepository reservations, RestaurantRepository restaurantRepo) {
        this.drops = drops;
        this.reservations = reservations;
        this.restaurantRepo = restaurantRepo;
    }

    public DropService(DropRepository drops, DropReservationRepository reservations) {
        this(drops, reservations, null);
    }

    @Transactional(readOnly = true)
    public List<DropResponseDTO> listUpcomingAndLive() {
        LocalDateTime now = LocalDateTime.now();
        return drops.findByEndsAtAfterOrderByStartsAtAsc(now).stream()
                .map(d -> DropResponseDTO.from(d, now)).toList();
    }

    @Transactional(readOnly = true)
    public DropResponseDTO get(int id) {
        Drop d = drops.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Drop not found"));
        return DropResponseDTO.from(d, LocalDateTime.now());
    }

    @Transactional
    public ReservationResponseDTO reserve(int dropId, String email) {
        Drop drop = drops.findById(dropId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Drop not found"));

        if (reservations.existsByDrop_IdAndCustomerEmailAndStatusIn(
                dropId, email, List.of(ReservationStatus.HELD, ReservationStatus.CONFIRMED))) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "You already have a slot in this drop");
        }

        LocalDateTime now = LocalDateTime.now();
        // The single atomic check-and-increment. No read-then-write race.
        if (drops.tryReserveSlot(dropId, now) == 0) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Drop is not live or is sold out");
        }

        DropReservation r = new DropReservation();
        r.setDrop(drop);
        r.setCustomerEmail(email);
        r.setStatus(ReservationStatus.HELD);
        r.setCreatedAt(now);
        r.setExpiresAt(now.plus(HOLD_DURATION));
        try {
            return ReservationResponseDTO.from(reservations.saveAndFlush(r));
        } catch (org.springframework.dao.DataIntegrityViolationException ex) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "You already have a slot in this drop");
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
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Reservation not found"));
        if (!r.getCustomerEmail().equalsIgnoreCase(email)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Not your reservation");
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
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Reservation not found"));

        if (!r.getCustomerEmail().equalsIgnoreCase(email)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Not your reservation");
        }
        if (r.getStatus() != ReservationStatus.HELD || r.getExpiresAt().isBefore(now) || r.getOrderId() != null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Reservation expired or already used");
        }
        throw new ResponseStatusException(HttpStatus.CONFLICT, "Could not attach order to reservation");
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

        // 3. If EXPIRED, CANCELLED, or RELEASED, customer paid after hold lapsed.
        // The reclaim path must FIRST win an atomic conditional status transition (EXPIRED/CANCELLED -> CONFIRMED)
        // and ONLY THEN tryReserveSlot, or compensate on failure, so two simultaneous webhooks can never double-increment.
        if (r.getStatus() == ReservationStatus.EXPIRED || r.getStatus() == ReservationStatus.CANCELLED || r.getStatus() == ReservationStatus.RELEASED) {
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
            // If already CANCELLED, RELEASED, or EXPIRED, do nothing (never double-release).
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
        return DropResponseDTO.from(drops.save(d), LocalDateTime.now());
    }

    @Transactional
    public DropResponseDTO updateDrop(int id, CreateDropRequestDTO req) {
        Drop d = drops.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Drop not found"));
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
        return DropResponseDTO.from(drops.save(d), LocalDateTime.now());
    }

    @Transactional
    public void deleteDrop(int id) {
        if (!drops.existsById(id)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Drop not found");
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
