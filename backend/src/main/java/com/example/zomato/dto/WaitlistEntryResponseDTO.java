package com.example.zomato.dto;

import com.example.zomato.entity.DropWaitlistEntry;

import java.time.LocalDateTime;

/**
 * @param position 1-based place in line while WAITING; 0 once OFFERED (a slot is being held for you)
 * @param offerExpiresAt when the offered hold lapses (only while OFFERED)
 */
public record WaitlistEntryResponseDTO(int entryId,
                                       int dropId,
                                       String status,
                                       int position,
                                       Integer reservationId,
                                       LocalDateTime offerExpiresAt,
                                       LocalDateTime serverTime) {

    public static WaitlistEntryResponseDTO from(DropWaitlistEntry e, int position, LocalDateTime offerExpiresAt) {
        return new WaitlistEntryResponseDTO(e.getId(), e.getDrop().getId(), e.getStatus().name(), position,
                e.getReservationId(), offerExpiresAt, LocalDateTime.now());
    }
}
