package com.example.zomato.events;

import java.time.LocalDateTime;

/** A freed slot was handed to a waitlisted customer as a HELD reservation. */
public record WaitlistOfferedEvent(String customerEmail, int dropId, String dropTitle,
                                   int reservationId, LocalDateTime expiresAt) {}
