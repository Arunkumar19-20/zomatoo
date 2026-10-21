package com.example.zomato.controller;

import com.example.zomato.dto.PaymentResponseDTO;
import com.example.zomato.services.PaymentService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.Map;

@RestController
@RequestMapping("/payment")
public class PaymentController {

    private final PaymentService paymentService;

    public PaymentController(PaymentService paymentService) {
        this.paymentService = paymentService;
    }

    @PostMapping("/create")
    public ResponseEntity<PaymentResponseDTO> createPayment(
            Authentication authentication,
            @RequestParam(required = false) Integer orderId,
            @RequestBody(required = false) Map<String, Object> body) throws Exception {

        if (authentication == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Authentication required");
        }

        Integer resolvedOrderId = orderId;
        if (resolvedOrderId == null && body != null && body.containsKey("orderId")) {
            resolvedOrderId = Integer.valueOf(body.get("orderId").toString());
        }

        if (resolvedOrderId == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "orderId is required");
        }

        PaymentResponseDTO response = paymentService.createPaymentIntent(resolvedOrderId, authentication.getName());
        return ResponseEntity.ok(response);
    }

    @PostMapping("/webhook")
    public ResponseEntity<String> stripeWebhook(
            @RequestBody String payload,
            @RequestHeader(value = "Stripe-Signature", required = false) String sigHeader) {

        paymentService.handleStripeWebhook(payload, sigHeader);
        return ResponseEntity.ok("Webhook processed successfully");
    }
}

