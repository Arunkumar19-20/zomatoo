package com.example.zomato.events;

/** A drop hold timed out without payment. Listeners cancel the linked unpaid order, if any. */
public record HoldLapsedEvent(int reservationId, Integer orderId) {}
