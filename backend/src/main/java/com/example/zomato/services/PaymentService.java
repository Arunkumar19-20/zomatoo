package com.example.zomato.services;

import com.example.zomato.dto.PaymentResponseDTO;
import com.example.zomato.entity.Order;
import com.example.zomato.entity.Payment;
import com.example.zomato.entity.PaymentStatus;
import com.example.zomato.entity.User;
import com.example.zomato.entity.ProcessedWebhookEvent;
import com.example.zomato.repository.OrderRepository;
import com.example.zomato.repository.PaymentRepository;
import com.example.zomato.repository.ProcessedWebhookEventRepository;
import com.example.zomato.repository.UserRepository;
import com.stripe.Stripe;
import com.stripe.exception.SignatureVerificationException;
import com.stripe.model.Event;
import com.stripe.model.EventDataObjectDeserializer;
import com.stripe.model.PaymentIntent;
import com.stripe.model.Refund;
import com.stripe.model.StripeObject;
import com.stripe.net.RequestOptions;
import com.stripe.net.Webhook;
import com.stripe.param.PaymentIntentCreateParams;
import com.stripe.param.RefundCreateParams;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.Optional;

@Service
public class PaymentService {

    private static final Logger logger = LoggerFactory.getLogger(PaymentService.class);

    @Value("${stripe.secret.key:}")
    private String secretKey;

    @Value("${stripe.webhook.secret:}")
    private String webhookSecret;

    private final PaymentRepository paymentRepo;
    private final OrderRepository orderRepo;
    private final UserRepository userRepo;
    private final ProcessedWebhookEventRepository processedWebhookEventRepo;
    private final DropService dropService;
    private final com.example.zomato.gateway.StripeGateway stripeGateway;
    private final org.springframework.transaction.support.TransactionTemplate transactionTemplate;

    @Autowired
    public PaymentService(PaymentRepository paymentRepo,
                          OrderRepository orderRepo,
                          UserRepository userRepo,
                          ProcessedWebhookEventRepository processedWebhookEventRepo,
                          DropService dropService,
                          com.example.zomato.gateway.StripeGateway stripeGateway,
                          @Autowired(required = false) org.springframework.transaction.PlatformTransactionManager transactionManager) {
        this.paymentRepo = paymentRepo;
        this.orderRepo = orderRepo;
        this.userRepo = userRepo;
        this.processedWebhookEventRepo = processedWebhookEventRepo;
        this.dropService = dropService;
        this.stripeGateway = stripeGateway != null ? stripeGateway : new com.example.zomato.gateway.FakeStripeGateway();
        this.transactionTemplate = transactionManager != null ? new org.springframework.transaction.support.TransactionTemplate(transactionManager) : null;
    }

    public PaymentService(PaymentRepository paymentRepo,
                          OrderRepository orderRepo,
                          UserRepository userRepo,
                          ProcessedWebhookEventRepository processedWebhookEventRepo,
                          DropService dropService,
                          com.example.zomato.gateway.StripeGateway stripeGateway) {
        this(paymentRepo, orderRepo, userRepo, processedWebhookEventRepo, dropService, stripeGateway, null);
    }

    public PaymentService(PaymentRepository paymentRepo,
                          OrderRepository orderRepo,
                          UserRepository userRepo,
                          ProcessedWebhookEventRepository processedWebhookEventRepo,
                          DropService dropService) {
        this(paymentRepo, orderRepo, userRepo, processedWebhookEventRepo, dropService, new com.example.zomato.gateway.FakeStripeGateway(), null);
    }

    public PaymentService(PaymentRepository paymentRepo,
                          OrderRepository orderRepo,
                          UserRepository userRepo,
                          ProcessedWebhookEventRepository processedWebhookEventRepo) {
        this(paymentRepo, orderRepo, userRepo, processedWebhookEventRepo, null, new com.example.zomato.gateway.FakeStripeGateway(), null);
    }

    @Transactional
    public PaymentResponseDTO createPaymentIntent(int orderId, String userEmail) throws Exception {
        Order order = orderRepo.findById(orderId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Order not found"));

        User user = userRepo.findByEmail(userEmail).orElse(null);
        boolean isAdmin = user != null && ("ADMIN".equalsIgnoreCase(user.getRole()) || "ROLE_ADMIN".equalsIgnoreCase(user.getRole()));
        if (!isAdmin && (order.getCustomer() == null || !userEmail.equalsIgnoreCase(order.getCustomer().getEmail()))) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Access denied to this order");
        }

        double totalAmount = order.getTotalAmount();
        long amountInCents = Math.round(totalAmount * 100);
        if (amountInCents <= 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Order total amount must be greater than zero");
        }

        Optional<Payment> existingPaymentOpt = paymentRepo.findByOrder_OrderId(orderId);
        if (existingPaymentOpt.isPresent() && "SUCCESS".equalsIgnoreCase(existingPaymentOpt.get().getStatus())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Order is already paid");
        }

        if (existingPaymentOpt.isPresent() && "PENDING".equalsIgnoreCase(existingPaymentOpt.get().getStatus())
                && existingPaymentOpt.get().getTransactionId() != null) {
            Payment payment = existingPaymentOpt.get();
            try {
                PaymentIntent existingIntent = retrieveStripeIntent(payment.getTransactionId());
                if (existingIntent != null && !"canceled".equalsIgnoreCase(existingIntent.getStatus())) {
                    logger.info("Reusing existing pending Stripe PaymentIntent {} for order {}", existingIntent.getId(), orderId);
                    return new PaymentResponseDTO(
                            existingIntent.getClientSecret(),
                            existingIntent.getId(),
                            payment.getAmount(),
                            payment.getCurrency() != null ? payment.getCurrency() : "inr",
                            "PENDING",
                            orderId
                    );
                }
            } catch (Exception e) {
                logger.warn("Could not retrieve existing PaymentIntent {}, will create new one: {}", payment.getTransactionId(), e.getMessage());
            }
        }

        if (secretKey == null || secretKey.isBlank()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Stripe secret key is not configured");
        }

        Stripe.apiKey = secretKey;

        PaymentIntentCreateParams params = PaymentIntentCreateParams.builder()
                .setAmount(amountInCents)
                .setCurrency("inr")
                .addPaymentMethodType("card")
                .putMetadata("orderId", String.valueOf(orderId))
                .putMetadata("customerEmail", userEmail)
                .build();

        RequestOptions requestOptions = RequestOptions.builder()
                .setIdempotencyKey("order-payment-" + orderId)
                .build();

        logger.info("Creating Stripe PaymentIntent for order {} amount {}", orderId, amountInCents);
        PaymentIntent intent = executeStripeCall(params, requestOptions);

        Payment payment = existingPaymentOpt.orElseGet(Payment::new);
        payment.setOrder(order);
        payment.setAmount(totalAmount);
        payment.setCurrency("inr");
        payment.setMethod("STRIPE");
        payment.setStatus("PENDING");
        payment.setTransactionId(intent.getId());
        paymentRepo.save(payment);

        if (order.getPaymentStatus() != PaymentStatus.PENDING) {
            order.setPaymentStatus(PaymentStatus.PENDING);
            orderRepo.save(order);
        }

        return new PaymentResponseDTO(
                intent.getClientSecret(),
                intent.getId(),
                totalAmount,
                "inr",
                "PENDING",
                orderId
        );
    }

    public PaymentIntent executeStripeCall(PaymentIntentCreateParams params, RequestOptions requestOptions) throws Exception {
        return stripeGateway.createPaymentIntent(params, requestOptions);
    }

    public PaymentIntent retrieveStripeIntent(String paymentIntentId) throws Exception {
        return stripeGateway.retrievePaymentIntent(paymentIntentId);
    }

    public Refund executeStripeRefund(RefundCreateParams params, RequestOptions requestOptions) throws Exception {
        return stripeGateway.createRefund(params, requestOptions);
    }

    public PaymentIntent cancelStripeIntent(String paymentIntentId) throws Exception {
        return stripeGateway.cancelPaymentIntent(paymentIntentId);
    }

    @Transactional(noRollbackFor = ResponseStatusException.class)
    public boolean processRefund(int orderId, String reason) throws Exception {
        Optional<Payment> paymentOpt = paymentRepo.findByOrder_OrderId(orderId);
        if (paymentOpt.isEmpty()) {
            logger.warn("Cannot refund order {}: no payment record found", orderId);
            return false;
        }

        Payment payment = paymentOpt.get();
        if ("REFUNDED".equalsIgnoreCase(payment.getStatus())) {
            logger.info("Order {} is already REFUNDED. Skipping.", orderId);
            return true;
        }

        if (payment.getTransactionId() == null || payment.getTransactionId().isBlank()) {
            logger.warn("Cannot refund order {}: payment transactionId is null", orderId);
            return false;
        }

        RefundCreateParams params = RefundCreateParams.builder()
                .setPaymentIntent(payment.getTransactionId())
                .putMetadata("orderId", String.valueOf(orderId))
                .putMetadata("reason", reason != null ? reason : "Order cancelled")
                .build();

        RequestOptions requestOptions = RequestOptions.builder()
                .setIdempotencyKey("refund-order-" + orderId)
                .build();

        logger.info("Issuing Stripe refund for order {} intent {}", orderId, payment.getTransactionId());
        try {
            executeStripeRefund(params, requestOptions);
        } catch (Exception e) {
            logger.error("ALERT: Stripe refund failed for order {} intent {}: {}. Leaving order in retryable state.",
                    orderId, payment.getTransactionId(), e.getMessage(), e);
            payment.setStatus("REFUND_FAILED");
            paymentRepo.save(payment);
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Stripe refund failed: " + e.getMessage(), e);
        }

        payment.setStatus("REFUNDED");
        paymentRepo.save(payment);

        Order order = payment.getOrder();
        if (order != null) {
            order.setPaymentStatus(PaymentStatus.REFUNDED);
            order.setStatus("CANCELLED");
            orderRepo.save(order);
            if (dropService != null) {
                dropService.releaseByOrderId(orderId);
            }
        }
        return true;
    }

    public void handleStripeWebhook(String payload, String sigHeader) {
        if (webhookSecret == null || webhookSecret.isBlank()) {
            logger.warn("STRIPE_WEBHOOK_SECRET is not configured; skipping webhook signature validation.");
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Webhook secret not configured");
        }

        Event event;
        try {
            event = Webhook.constructEvent(payload, sigHeader, webhookSecret);
        } catch (SignatureVerificationException e) {
            logger.error("Invalid Stripe webhook signature", e);
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid webhook signature");
        } catch (Exception e) {
            logger.error("Error processing Stripe webhook payload", e);
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid webhook payload");
        }

        logger.info("Received Stripe webhook event: {} (id: {})", event.getType(), event.getId());

        // Fast-path idempotency check: if event has already been processed and committed, skip duplicate
        if (event.getId() != null && processedWebhookEventRepo.existsById(event.getId())) {
            logger.info("Event {} has already been processed. Skipping duplicate/replayed event.", event.getId());
            return;
        }

        // Webhook Idempotency & Transactional Boundary:
        // The event ID is inserted and flushed BEFORE business processing in the SAME database transaction.
        // 1. If processing crashes or fails, the transaction rolls back, which rolls back both the
        //    business state changes AND the event ID record, allowing subsequent Stripe webhook retries to succeed.
        // 2. If two concurrent deliveries arrive for the same event, the second one will hit the unique constraint
        //    on processed_webhook_events.event_id and throw DataIntegrityViolationException.
        //    This exception is caught and treated as "already processed" (HTTP 200), not an error.
        if (transactionTemplate != null) {
            try {
                transactionTemplate.execute(status -> {
                    processWebhookEventInTransaction(event);
                    return null;
                });
            } catch (org.springframework.dao.DataIntegrityViolationException ex) {
                logger.info("Event {} was concurrently processed or duplicate key violation caught: {}. Treating as already processed (HTTP 200).",
                        event.getId(), ex.getMessage());
            }
        } else {
            try {
                processWebhookEventInTransaction(event);
            } catch (org.springframework.dao.DataIntegrityViolationException ex) {
                logger.info("Event {} was concurrently processed (duplicate key): {}. Treating as already processed (HTTP 200).",
                        event.getId(), ex.getMessage());
            }
        }
    }

    private void processWebhookEventInTransaction(Event event) {
        if (event.getId() != null) {
            processedWebhookEventRepo.saveAndFlush(new ProcessedWebhookEvent(event.getId(), event.getType()));
        }
        doProcessEventPayload(event);
    }

    private void doProcessEventPayload(Event event) {
        // Note on deserializeUnsafe(): Calling deserializeUnsafe() is secure and safe here because the payload
        // has already undergone cryptographic signature verification with Stripe's webhook secret above
        // (via Webhook.constructEvent). deserializeUnsafe() allows fallback when the event payload was generated
        // with an API version that differs from the SDK version.
        if ("payment_intent.succeeded".equals(event.getType())) {
            EventDataObjectDeserializer deserializer = event.getDataObjectDeserializer();
            StripeObject stripeObject = deserializer.getObject().orElse(null);
            if (stripeObject == null) {
                try {
                    stripeObject = deserializer.deserializeUnsafe();
                } catch (Exception e) {
                    logger.warn("Failed to deserialize unsafe Stripe object: {}", e.getMessage());
                }
            }
            if (stripeObject instanceof PaymentIntent intent) {
                onPaymentSucceeded(intent);
            }
        } else if ("payment_intent.payment_failed".equals(event.getType())) {
            EventDataObjectDeserializer deserializer = event.getDataObjectDeserializer();
            StripeObject stripeObject = deserializer.getObject().orElse(null);
            if (stripeObject == null) {
                try {
                    stripeObject = deserializer.deserializeUnsafe();
                } catch (Exception e) {
                    logger.warn("Failed to deserialize unsafe Stripe object: {}", e.getMessage());
                }
            }
            if (stripeObject instanceof PaymentIntent intent) {
                onPaymentFailed(intent);
            }
        }
    }

    private void onPaymentSucceeded(PaymentIntent intent) {
        logger.info("Processing successful payment intent: {}", intent.getId());

        // 1. Metadata and order validation
        if (intent.getMetadata() == null || !intent.getMetadata().containsKey("orderId")) {
            logger.warn("Rejecting Stripe event: missing orderId in metadata");
            return;
        }
        int orderId;
        try {
            orderId = Integer.parseInt(intent.getMetadata().get("orderId"));
        } catch (NumberFormatException e) {
            logger.warn("Rejecting Stripe event: invalid orderId metadata: {}", intent.getMetadata().get("orderId"));
            return;
        }

        Order order = orderRepo.findById(orderId).orElse(null);
        if (order == null) {
            logger.warn("Rejecting Stripe event: order {} not found", orderId);
            return;
        }

        // 2. Amount verification: intent.getAmount() is in cents, order.getTotalAmount() is in currency units
        long expectedAmountInCents = Math.round(order.getTotalAmount() * 100);
        if (intent.getAmount() == null || intent.getAmount() != expectedAmountInCents) {
            logger.error("SECURITY ALERT: Stripe intent amount {} does not match expected order amount {}",
                    intent.getAmount(), expectedAmountInCents);
            return;
        }

        // 3. Update payment and order paymentStatus
        Optional<Payment> paymentOpt = paymentRepo.findByTransactionId(intent.getId());
        Payment payment = paymentOpt.orElseGet(Payment::new);
        if ("SUCCESS".equalsIgnoreCase(payment.getStatus())) {
            logger.info("Payment {} is already marked SUCCESS. Skipping.", payment.getId());
            return;
        }

        payment.setOrder(order);
        payment.setAmount(intent.getAmount() != null ? intent.getAmount() / 100.0 : (double) order.getTotalAmount());
        payment.setCurrency(intent.getCurrency());
        payment.setMethod("STRIPE");
        payment.setStatus("SUCCESS");
        payment.setTransactionId(intent.getId());
        paymentRepo.save(payment);

        // Terminal PAID state on order. Does NOT force order status to CONFIRMED (restaurant owner action).
        order.setPaymentStatus(PaymentStatus.PAID);
        orderRepo.save(order);

        if (dropService != null && !dropService.confirmByOrderId(orderId)) {
            logger.error("Drop slot lost for paid order {}; refunding", orderId);
            try {
                processRefund(orderId, "Drop sold out before payment completed");
            } catch (Exception e) {
                logger.error("Refund failed for order {}", orderId, e);
            }
        }
    }

    private void onPaymentFailed(PaymentIntent intent) {
        logger.warn("Processing failed payment intent: {}", intent.getId());
        Optional<Payment> paymentOpt = paymentRepo.findByTransactionId(intent.getId());
        paymentOpt.ifPresent(payment -> {
            Order order = payment.getOrder();
            // Terminal PAID guard: late payment_failed event must not downgrade an already paid order!
            if (order != null && order.getPaymentStatus() == PaymentStatus.PAID) {
                logger.info("Order {} is already PAID. Ignoring late payment_failed event for intent {}.",
                        order.getOrderId(), intent.getId());
                return;
            }
            payment.setStatus("FAILED");
            paymentRepo.save(payment);

            if (order != null) {
                order.setPaymentStatus(PaymentStatus.FAILED);
                orderRepo.save(order);
            }
        });
    }
}

