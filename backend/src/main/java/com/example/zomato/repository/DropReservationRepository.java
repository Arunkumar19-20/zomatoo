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

    List<DropReservation> findByDrop_IdAndCustomerEmailAndStatusIn(int dropId, String email, Collection<ReservationStatus> statuses);

    long countByDrop_IdAndCustomerEmailAndStatusIn(int dropId, String email, Collection<ReservationStatus> statuses);

    @Query("select r.id from DropReservation r where r.status = com.example.zomato.entity.ReservationStatus.HELD and r.expiresAt < :now")
    List<Integer> findStaleHeldIds(@Param("now") LocalDateTime now);

    /** Atomic HELD -> target transition; guarantees a slot is released at most once. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update DropReservation r set r.status = :to where r.id = :id " +
           "and r.status = com.example.zomato.entity.ReservationStatus.HELD")
    int transitionFromHeld(@Param("id") int id, @Param("to") ReservationStatus to);

    /** Atomic attachOrder: conditional UPDATE requiring HELD, not expired, caller email, and orderId IS NULL. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update DropReservation r set r.orderId = :orderId, " +
           "r.expiresAt = case when r.expiresAt > :newExpiresAt then r.expiresAt else :newExpiresAt end " +
           "where r.id = :id and lower(r.customerEmail) = lower(:email) " +
           "and r.status = com.example.zomato.entity.ReservationStatus.HELD " +
           "and r.expiresAt >= :now and r.orderId is null")
    int attachOrderAtomic(@Param("id") int id,
                          @Param("orderId") int orderId,
                          @Param("email") String email,
                          @Param("now") LocalDateTime now,
                          @Param("newExpiresAt") LocalDateTime newExpiresAt);

    /** Payment-aware extension: pushes expiry forward only while still HELD, never backwards. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update DropReservation r set r.expiresAt = :newExpiresAt " +
           "where r.id = :id and r.status = com.example.zomato.entity.ReservationStatus.HELD " +
           "and r.expiresAt < :newExpiresAt")
    int extendExpiry(@Param("id") int id, @Param("newExpiresAt") LocalDateTime newExpiresAt);

    /** Atomic expiry: only transitions to EXPIRED if still HELD and expiresAt < now. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update DropReservation r set r.status = :to " +
           "where r.id = :id and r.status = com.example.zomato.entity.ReservationStatus.HELD and r.expiresAt < :now")
    int transitionFromHeldIfExpired(@Param("id") int id,
                                    @Param("to") ReservationStatus to,
                                    @Param("now") LocalDateTime now);

    /** Atomic CONFIRMED -> CANCELLED transition; guarantees slot is released once even under duplicate refund calls. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update DropReservation r set r.status = com.example.zomato.entity.ReservationStatus.CANCELLED " +
           "where r.id = :id and r.status = com.example.zomato.entity.ReservationStatus.CONFIRMED")
    int transitionFromConfirmedToCancelled(@Param("id") int id);

    /** Backward-compatible alias for transitionFromConfirmedToCancelled. */
    default int transitionFromConfirmedToReleased(int id) {
        return transitionFromConfirmedToCancelled(id);
    }

    /** Atomic transition to CONFIRMED for reservations that lapsed (EXPIRED or CANCELLED) and are re-claiming a slot. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update DropReservation r set r.status = com.example.zomato.entity.ReservationStatus.CONFIRMED " +
           "where r.id = :id and r.status in (com.example.zomato.entity.ReservationStatus.EXPIRED, com.example.zomato.entity.ReservationStatus.CANCELLED)")
    int transitionFromLapsedToConfirmed(@Param("id") int id);

    /** Backward-compatible alias for transitionFromLapsedToConfirmed. */
    default int transitionFromExpiredOrReleasedToConfirmed(int id) {
        return transitionFromLapsedToConfirmed(id);
    }

    /** Atomic conditional status rollback/compensation. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update DropReservation r set r.status = :to " +
           "where r.id = :id and r.status = :from")
    int transitionStatus(@Param("id") int id,
                         @Param("from") ReservationStatus from,
                         @Param("to") ReservationStatus to);

    /** Active reservations for caller (HELD and not expired, or CONFIRMED). */
    @Query("select r from DropReservation r where lower(r.customerEmail) = lower(:email) " +
           "and (r.status = com.example.zomato.entity.ReservationStatus.CONFIRMED " +
           "or (r.status = com.example.zomato.entity.ReservationStatus.HELD and r.expiresAt > :now)) " +
           "order by r.id desc")
    List<DropReservation> findActiveByCustomerEmail(@Param("email") String email, @Param("now") LocalDateTime now);

    @Modifying
    @Query("delete from DropReservation r where r.drop.id = :dropId")
    void deleteByDrop_Id(@Param("dropId") int dropId);

    /** Slot accounting invariant queries: count active reservations holding slots. */
    long countByDrop_IdAndStatusIn(int dropId, Collection<ReservationStatus> statuses);

    long countByDrop_IdAndStatus(int dropId, ReservationStatus status);

    /** Remembers the search phrase on a still-held reservation of this customer. Returns rows updated (0 or 1). */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update DropReservation r set r.searchAttribution = :phrase, r.searchAttributionAt = :at " +
           "where r.id = :id and lower(r.customerEmail) = lower(:email) and r.status = com.example.zomato.entity.ReservationStatus.HELD")
    int setAttribution(@Param("id") int id, @Param("email") String email, @Param("phrase") String phrase, @Param("at") LocalDateTime at);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update DropReservation r set r.searchAttribution = null, r.searchAttributionAt = null where r.id = :id")
    int clearAttribution(@Param("id") int id);

    /** Forgets the search phrase on reservations older than the window. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update DropReservation r set r.searchAttribution = null, r.searchAttributionAt = null " +
           "where r.searchAttribution is not null and r.searchAttributionAt < :cutoff")
    int clearAttributionOlderThan(@Param("cutoff") LocalDateTime cutoff);
}
