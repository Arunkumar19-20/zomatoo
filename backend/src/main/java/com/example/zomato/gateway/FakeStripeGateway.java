package com.example.zomato.gateway;

import com.stripe.model.PaymentIntent;
import com.stripe.model.Refund;
import com.stripe.net.RequestOptions;
import com.stripe.param.PaymentIntentCreateParams;
import com.stripe.param.RefundCreateParams;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Fake in-memory implementation of StripeGateway used in the test and demo profiles.
 * Prevents real external HTTP network calls during automated test suites.
 */
@Component
@Profile({"test", "demo"})
public class FakeStripeGateway implements StripeGateway {

    private final Map<String, PaymentIntent> intents = new ConcurrentHashMap<>();
    private final AtomicLong counter = new AtomicLong(1000);
    private volatile boolean simulateRefundFailure = false;

    public void setSimulateRefundFailure(boolean simulateRefundFailure) {
        this.simulateRefundFailure = simulateRefundFailure;
    }

    @Override
    public PaymentIntent createPaymentIntent(PaymentIntentCreateParams params, RequestOptions requestOptions) throws Exception {
        String id = "pi_fake_" + counter.incrementAndGet();
        PaymentIntent intent = new PaymentIntent();
        intent.setId(id);
        intent.setClientSecret(id + "_secret_mock");
        intent.setStatus("requires_payment_method");
        if (params.getAmount() != null) {
            intent.setAmount(params.getAmount());
        }
        intents.put(id, intent);
        return intent;
    }

    @Override
    public PaymentIntent retrievePaymentIntent(String paymentIntentId) throws Exception {
        return intents.computeIfAbsent(paymentIntentId, id -> {
            PaymentIntent intent = new PaymentIntent();
            intent.setId(id);
            intent.setStatus("requires_payment_method");
            return intent;
        });
    }

    @Override
    public PaymentIntent cancelPaymentIntent(String paymentIntentId) throws Exception {
        PaymentIntent intent = retrievePaymentIntent(paymentIntentId);
        intent.setStatus("canceled");
        return intent;
    }

    @Override
    public Refund createRefund(RefundCreateParams params, RequestOptions requestOptions) throws Exception {
        if (simulateRefundFailure) {
            throw new RuntimeException("Simulated Stripe gateway connection timeout during refund");
        }
        Refund refund = new Refund();
        refund.setId("re_fake_" + counter.incrementAndGet());
        refund.setStatus("succeeded");
        return refund;
    }
}
