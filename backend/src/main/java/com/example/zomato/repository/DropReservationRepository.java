package com.example.zomato.repository;

import com.example.zomato.entity.DropReservation;
import com.example.zomato.entity.ReservationStatus;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface DropReservationRepository extends JpaRepository<DropReservation, Integer> {

    Optional<DropReservation> findByOrderId(Integer orderId);

    boolean existsByDrop_IdAndCustomerEmailAndStatusIn(int dropId, String email, Collection<ReservationStatus> statuses);

    @Query("select r.id from DropReservation r where r.status = com.example.zomato.entity.ReservationStatus.HELD and r.expiresAt < :now")
    List<Integer> findStaleHeldIds(@Param("now") LocalDateTime now);

    /** Atomic HELD -> target transition; guarantees a slot is released at most once. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update DropReservation r set r.status = :to where r.id = :id " +
           "and r.status = com.example.zomato.entity.ReservationStatus.HELD")
    int transitionFromHeld(@Param("id") int id, @Param("to") ReservationStatus to);

    /** Atomic attachOrder: conditional UPDATE requiring HELD, not expired, caller email, and orderId IS NULL. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update DropReservation r set r.orderId = :orderId, r.expiresAt = :newExpiresAt " +
           "where r.id = :id and lower(r.customerEmail) = lower(:email) " +
           "and r.status = com.example.zomato.entity.ReservationStatus.HELD " +
           "and r.expiresAt >= :now and r.orderId is null")
    int attachOrderAtomic(@Param("id") int id,
                          @Param("orderId") int orderId,
                          @Param("email") String email,
                          @Param("now") LocalDateTime now,
                          @Param("newExpiresAt") LocalDateTime newExpiresAt);

    /** Atomic expiry: only transitions to EXPIRED if still HELD and expiresAt < now. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update DropReservation r set r.status = :to " +
           "where r.id = :id and r.status = com.example.zomato.entity.ReservationStatus.HELD and r.expiresAt < :now")
    int transitionFromHeldIfExpired(@Param("id") int id,
                                    @Param("to") ReservationStatus to,
                                    @Param("now") LocalDateTime now);

    /** Atomic CONFIRMED -> RELEASED transition; guarantees slot is released once even under duplicate refund calls. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update DropReservation r set r.status = com.example.zomato.entity.ReservationStatus.RELEASED " +
           "where r.id = :id and r.status = com.example.zomato.entity.ReservationStatus.CONFIRMED")
    int transitionFromConfirmedToReleased(@Param("id") int id);

    /** Atomic transition to CONFIRMED for reservations that lapsed and are re-claiming a slot. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update DropReservation r set r.status = com.example.zomato.entity.ReservationStatus.CONFIRMED " +
           "where r.id = :id and r.status in (com.example.zomato.entity.ReservationStatus.EXPIRED, com.example.zomato.entity.ReservationStatus.RELEASED)")
    int transitionFromExpiredOrReleasedToConfirmed(@Param("id") int id);
}
