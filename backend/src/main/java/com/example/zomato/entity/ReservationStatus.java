package com.example.zomato.entity;

public enum ReservationStatus {
    HELD,
    CONFIRMED,
    CANCELLED,
    EXPIRED,
    RELEASED // Legacy synonym for CANCELLED
}
