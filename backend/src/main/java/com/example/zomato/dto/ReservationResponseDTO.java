package com.example.zomato.dto;

import com.example.zomato.entity.DropReservation;
import java.time.LocalDateTime;

public record ReservationResponseDTO(int reservationId, int dropId, String status,
                                     LocalDateTime expiresAt, Integer orderId) {
    public static ReservationResponseDTO from(DropReservation r) {
        return new ReservationResponseDTO(r.getId(), r.getDrop().getId(), r.getStatus().name(),
                r.getExpiresAt(), r.getOrderId());
    }
}
