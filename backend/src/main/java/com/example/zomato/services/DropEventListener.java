package com.example.zomato.services;

import com.example.zomato.entity.Notification;
import com.example.zomato.events.HoldLapsedEvent;
import com.example.zomato.events.WaitlistOfferedEvent;
import com.example.zomato.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Side effects of drop state changes. They run after the reservation transaction commits so a
 * failure here (Stripe outage, notification error) can never roll back slot accounting.
 */
@Component
public class DropEventListener {

    private static final Logger log = LoggerFactory.getLogger(DropEventListener.class);

    private final OrderService orderService;
    private final NotificationService notificationService;
    private final UserRepository userRepository;

    public DropEventListener(OrderService orderService,
                             NotificationService notificationService,
                             UserRepository userRepository) {
        this.orderService = orderService;
        this.notificationService = notificationService;
        this.userRepository = userRepository;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onHoldLapsed(HoldLapsedEvent event) {
        if (event.orderId() == null) return;
        try {
            orderService.cancelOrderForLapsedHold(event.orderId());
        } catch (Exception e) {
            log.error("Could not cancel order {} after hold {} lapsed: {}", event.orderId(), event.reservationId(), e.getMessage(), e);
        }
    }

    // REQUIRES_NEW: at AFTER_COMMIT the original transaction can no longer commit anything, so a plain save here
    // would silently be dropped.
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onWaitlistOffered(WaitlistOfferedEvent event) {
        try {
            userRepository.findByEmail(event.customerEmail()).ifPresent(user -> {
                Notification n = new Notification();
                n.setUser(user);
                n.setType("DROP_SLOT_OFFERED");
                n.setMessage("A slot opened up for \"" + event.dropTitle() + "\". It is held for you until "
                        + event.expiresAt() + " - check out now to keep it.");
                notificationService.send(n);
            });
        } catch (Exception e) {
            log.warn("Could not notify {} about waitlist offer: {}", event.customerEmail(), e.getMessage());
        }
    }
}
