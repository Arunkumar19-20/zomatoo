package com.example.zomato.gateway;

import com.stripe.Stripe;
import com.stripe.model.PaymentIntent;
import com.stripe.model.Refund;
import com.stripe.net.RequestOptions;
import com.stripe.param.PaymentIntentCreateParams;
import com.stripe.param.RefundCreateParams;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

/**
 * Production implementation of StripeGateway calling real Stripe API.
 * Active in all non-test profiles (!test).
 * Fails application startup if Stripe secret key is missing or configured with mock values.
 */
@Component
@Profile("!test & !demo")
public class DefaultStripeGateway implements StripeGateway {

    private static final Logger log = LoggerFactory.getLogger(DefaultStripeGateway.class);

    @Value("${stripe.secret.key:}")
    private String secretKey;

    @PostConstruct
    public void validateConfiguration() {
        if (secretKey == null || secretKey.isBlank() || secretKey.startsWith("sk_test_mock") || "mock".equalsIgnoreCase(secretKey)) {
            throw new IllegalStateException(
                    "Production/Non-test profile requires a valid Stripe secret key, but found missing or mock key: '" + secretKey + "'");
        }
        Stripe.apiKey = secretKey;
        log.info("StripeGateway initialized successfully with production secret key.");
    }

    @Override
    public PaymentIntent createPaymentIntent(PaymentIntentCreateParams params, RequestOptions requestOptions) throws Exception {
        return PaymentIntent.create(params, requestOptions);
    }

    @Override
    public PaymentIntent retrievePaymentIntent(String paymentIntentId) throws Exception {
        return PaymentIntent.retrieve(paymentIntentId);
    }

    @Override
    public PaymentIntent cancelPaymentIntent(String paymentIntentId) throws Exception {
        PaymentIntent intent = retrievePaymentIntent(paymentIntentId);
        return intent != null ? intent.cancel() : null;
    }

    @Override
    public Refund createRefund(RefundCreateParams params, RequestOptions requestOptions) throws Exception {
        return Refund.create(params, requestOptions);
    }
}
