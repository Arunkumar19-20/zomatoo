package com.example.zomato.services;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class OrderCleanupScheduler {

    private static final Logger logger = LoggerFactory.getLogger(OrderCleanupScheduler.class);

    private final OrderService orderService;

    @Value("${app.order.abandoned-timeout-minutes:15}")
    private int abandonedTimeoutMinutes;

    public OrderCleanupScheduler(OrderService orderService) {
        this.orderService = orderService;
    }

    @Scheduled(fixedDelayString = "${app.order.cleanup-interval-ms:300000}")
    public void cleanupAbandonedOrders() {
        logger.debug("Running scheduled abandoned order cleanup job (timeout: {} minutes)", abandonedTimeoutMinutes);
        try {
            int cancelled = orderService.cancelUnpaidAbandonedOrders(abandonedTimeoutMinutes);
            if (cancelled > 0) {
                logger.info("Scheduled cleanup job cancelled {} unpaid abandoned orders", cancelled);
            }
        } catch (Exception e) {
            logger.error("Error during scheduled abandoned order cleanup: {}", e.getMessage(), e);
        }
    }
}
