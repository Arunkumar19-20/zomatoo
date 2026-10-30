package com.example.zomato.repository;

import com.example.zomato.entity.Drop;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;

public interface DropRepository extends JpaRepository<Drop, Integer> {

    List<Drop> findByEndsAtAfterOrderByStartsAtAsc(LocalDateTime now);

    /** Atomic: succeeds only if the drop is live AND a slot is free. Returns rows updated (0 or 1). */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update Drop d set d.reservedSlots = d.reservedSlots + 1 " +
           "where d.id = :id and d.reservedSlots < d.totalSlots " +
           "and d.startsAt <= :now and d.endsAt > :now")
    int tryReserveSlot(@Param("id") int id, @Param("now") LocalDateTime now);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update Drop d set d.reservedSlots = d.reservedSlots - 1 " +
           "where d.id = :id and d.reservedSlots > 0")
    int releaseSlot(@Param("id") int id);

    /** Drops that are live right now, still have a slot, and are for one of these dishes. */
    @Query("select d from Drop d where d.menuItemId in :itemIds and d.startsAt <= :now and d.endsAt > :now and d.reservedSlots < d.totalSlots order by d.endsAt asc")
    List<Drop> liveForItems(@Param("itemIds") java.util.Collection<Integer> itemIds, @Param("now") LocalDateTime now);
}
