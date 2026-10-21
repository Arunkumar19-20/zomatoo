package com.example.zomato.gateway;

import com.stripe.model.PaymentIntent;
import com.stripe.model.Refund;
import com.stripe.net.RequestOptions;
import com.stripe.param.PaymentIntentCreateParams;
import com.stripe.param.RefundCreateParams;

/**
 * Gateway abstraction for Stripe payment operations.
 * Isolates external Stripe API network calls from business logic.
 */
public interface StripeGateway {

    PaymentIntent createPaymentIntent(PaymentIntentCreateParams params, RequestOptions requestOptions) throws Exception;

    PaymentIntent retrievePaymentIntent(String paymentIntentId) throws Exception;

    PaymentIntent cancelPaymentIntent(String paymentIntentId) throws Exception;

    Refund createRefund(RefundCreateParams params, RequestOptions requestOptions) throws Exception;
}
