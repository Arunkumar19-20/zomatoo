package com.example.zomato.services;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Retries failed Stripe refunds with back-off (see Payment.nextRefundAt). */
@Component
public class RefundRetryScheduler {

    private static final Logger log = LoggerFactory.getLogger(RefundRetryScheduler.class);

    private final PaymentService paymentService;

    public RefundRetryScheduler(PaymentService paymentService) { this.paymentService = paymentService; }

    @Scheduled(fixedDelayString = "${payments.refund-retry-ms:60000}")
    public void retryFailedRefunds() {
        try {
            int ok = paymentService.retryFailedRefunds();
            if (ok > 0) log.info("Refund retry job completed {} refund(s)", ok);
        } catch (Exception e) {
            log.error("Refund retry job failed: {}", e.getMessage(), e);
        }
    }
}
