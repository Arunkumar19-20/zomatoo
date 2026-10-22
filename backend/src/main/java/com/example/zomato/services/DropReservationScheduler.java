package com.example.zomato.services;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** The single owner of releasing drop slots: expired holds first, then waitlist upkeep. */
@Component
public class DropReservationScheduler {

    private static final Logger log = LoggerFactory.getLogger(DropReservationScheduler.class);

    private final DropService dropService;

    public DropReservationScheduler(DropService dropService) { this.dropService = dropService; }

    @Scheduled(fixedDelayString = "${drops.expiry-sweep-ms:15000}")
    public void sweep() {
        run("expire stale holds", dropService::expireStaleHolds);
        run("expire ended waitlists", dropService::expireEndedWaitlists);
        run("promote waitlists", dropService::promoteWaitlists);
    }

    private void run(String what, java.util.function.IntSupplier task) {
        try {
            int n = task.getAsInt();
            if (n > 0) log.info("Drop sweep: {} -> {}", what, n);
        } catch (Exception e) {
            log.error("Drop sweep failed to {}: {}", what, e.getMessage(), e);
        }
    }
}
