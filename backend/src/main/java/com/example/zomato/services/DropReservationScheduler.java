package com.example.zomato.services;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class DropReservationScheduler {
    private final DropService dropService;

    public DropReservationScheduler(DropService dropService) { this.dropService = dropService; }

    @Scheduled(fixedDelay = 30_000)
    public void expireStaleHolds() { dropService.expireStaleHolds(); }
}
