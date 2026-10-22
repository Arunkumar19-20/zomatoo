package com.example.zomato.repository;

import com.example.zomato.entity.DropWaitlistEntry;
import com.example.zomato.entity.WaitlistStatus;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface DropWaitlistRepository extends JpaRepository<DropWaitlistEntry, Integer> {

    /** Oldest waiting entry for a drop (FIFO by id). */
    Optional<DropWaitlistEntry> findFirstByDrop_IdAndStatusOrderByIdAsc(int dropId, WaitlistStatus status);

    @Query("select w from DropWaitlistEntry w where w.drop.id = :dropId and lower(w.customerEmail) = lower(:email) " +
           "and w.status in :statuses order by w.id desc")
    List<DropWaitlistEntry> findActiveForUser(@Param("dropId") int dropId,
                                              @Param("email") String email,
                                              @Param("statuses") Collection<WaitlistStatus> statuses);

    @Query("select w from DropWaitlistEntry w where lower(w.customerEmail) = lower(:email) " +
           "and w.status in :statuses order by w.id asc")
    List<DropWaitlistEntry> findAllActiveForUser(@Param("email") String email,
                                                 @Param("statuses") Collection<WaitlistStatus> statuses);

    long countByDrop_IdAndStatus(int dropId, WaitlistStatus status);

    long countByDrop_IdAndStatusAndIdLessThan(int dropId, WaitlistStatus status, int id);

    /** Atomic status transition; returns 1 only for the single caller that wins it. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update DropWaitlistEntry w set w.status = :to where w.id = :id and w.status = :from")
    int transition(@Param("id") int id, @Param("from") WaitlistStatus from, @Param("to") WaitlistStatus to);

    /** Links an entry that just moved WAITING -> OFFERED to the HELD reservation created for it. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update DropWaitlistEntry w set w.reservationId = :reservationId, w.offeredAt = :at where w.id = :id")
    int markOffered(@Param("id") int id, @Param("reservationId") int reservationId, @Param("at") LocalDateTime at);

    /** Live drops that have people waiting while a slot is actually free (safety net for missed hand-offs). */
    @Query("select distinct w.drop.id from DropWaitlistEntry w where w.status = com.example.zomato.entity.WaitlistStatus.WAITING " +
           "and w.drop.reservedSlots < w.drop.totalSlots and w.drop.startsAt <= :now and w.drop.endsAt > :now")
    List<Integer> findDropIdsWithWaitersAndFreeSlots(@Param("now") LocalDateTime now);

    /** Settles the entry that was offered via the given reservation (claimed / lapsed / left). */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update DropWaitlistEntry w set w.status = :to where w.reservationId = :reservationId and w.status = :from")
    int transitionByReservation(@Param("reservationId") int reservationId,
                                @Param("from") WaitlistStatus from,
                                @Param("to") WaitlistStatus to);

    /** Drop ended: nobody still WAITING can ever be served. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update DropWaitlistEntry w set w.status = com.example.zomato.entity.WaitlistStatus.EXPIRED " +
           "where w.status = com.example.zomato.entity.WaitlistStatus.WAITING " +
           "and w.drop.id in (select d.id from Drop d where d.endsAt <= :now)")
    int expireForEndedDrops(@Param("now") LocalDateTime now);
}
