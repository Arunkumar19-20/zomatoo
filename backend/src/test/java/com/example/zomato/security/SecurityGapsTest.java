package com.example.zomato.security;

import com.example.zomato.dto.RefreshTokenRequest;
import com.example.zomato.entity.*;
import com.example.zomato.repository.*;
import com.example.zomato.services.PaymentService;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
public class SecurityGapsTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private ProcessedWebhookEventRepository processedWebhookEventRepository;

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private PaymentRepository paymentRepository;

    @Autowired
    private CartItemRepository cartItemRepository;

    @Autowired
    private CartRepository cartRepository;

    @Autowired
    private CustomerRepository customerRepository;

    @Autowired
    private RateLimitingService rateLimitingService;

    @Autowired
    private PaymentService paymentService;

    @Autowired
    private com.example.zomato.controller.PaymentController paymentController;

    @Autowired
    private com.example.zomato.services.AuthenticationService authenticationService;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @BeforeEach
    void setUp() {
        authenticationService.setClock(Clock.systemDefaultZone());
        paymentRepository.deleteAll();
        orderRepository.deleteAll();
        cartItemRepository.deleteAll();
        cartRepository.deleteAll();
        customerRepository.deleteAll();
        refreshTokenRepository.deleteAll();
        processedWebhookEventRepository.deleteAll();
        userRepository.deleteAll();
        rateLimitingService.reset();
    }

    // -------------------------------------------------------------
    // 1. TOKEN MODEL: ACCESS TOKEN + REFRESH TOKEN ROTATION
    // -------------------------------------------------------------
    @Test
    void testRefreshTokenRotationAndRevocation() throws Exception {
        User user = new User("Dave", "dave@example.com", "CUSTOMER");
        user.setPassword(passwordEncoder.encode("Password123!"));
        user.setEmailVerified(true);
        userRepository.save(user);

        // Login to get tokens
        String loginJson = """
            {
                "email": "dave@example.com",
                "password": "Password123!"
            }
            """;

        var loginResult = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginJson))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                .andExpect(jsonPath("$.expiresIn").value(900))
                .andReturn();

        String accessToken1 = JsonPath.read(loginResult.getResponse().getContentAsString(), "$.accessToken");
        String refreshToken1 = JsonPath.read(loginResult.getResponse().getContentAsString(), "$.refreshToken");

        // Verify refresh token is stored hashed in DB
        RefreshToken storedToken1 = refreshTokenRepository.findAll().get(0);
        assertNotEquals(refreshToken1, storedToken1.getTokenHash());
        assertFalse(storedToken1.isRevoked());

        // Call /api/auth/refresh with refreshToken1
        String refreshJson = String.format("""
            {
                "refreshToken": "%s"
            }
            """, refreshToken1);

        var refreshResult = mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(refreshJson))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                .andExpect(jsonPath("$.expiresIn").value(900))
                .andReturn();

        String accessToken2 = JsonPath.read(refreshResult.getResponse().getContentAsString(), "$.accessToken");
        String refreshToken2 = JsonPath.read(refreshResult.getResponse().getContentAsString(), "$.refreshToken");

        assertNotEquals(refreshToken1, refreshToken2);

        // Expire the 15-second grace window to test full family revocation on reuse
        RefreshToken rotatedToken1 = refreshTokenRepository.findAll().stream()
                .filter(t -> t.isRevoked() && t.getRotatedAt() != null)
                .findFirst().orElseThrow();
        rotatedToken1.setRotatedAt(LocalDateTime.now().minusSeconds(20));
        refreshTokenRepository.save(rotatedToken1);

        // Attempting to reuse old refreshToken1 outside grace window MUST FAIL with reuse detection
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(refreshJson))
                .andExpect(status().isUnauthorized());

        // Because token reuse was detected, the entire token family was revoked!
        // Even the newer refreshToken2 MUST NOW BE INVALIDATED to protect the user against token theft
        String refreshJson2 = String.format("""
            {
                "refreshToken": "%s"
            }
            """, refreshToken2);

        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(refreshJson2))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void testLogoutRevokesRefreshToken() throws Exception {
        User user = new User("Lou", "lou@example.com", "CUSTOMER");
        user.setPassword(passwordEncoder.encode("Password123!"));
        user.setEmailVerified(true);
        userRepository.save(user);

        String loginJson = """
            {
                "email": "lou@example.com",
                "password": "Password123!"
            }
            """;

        var loginResult = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginJson))
                .andExpect(status().isOk())
                .andReturn();

        String refreshToken = JsonPath.read(loginResult.getResponse().getContentAsString(), "$.refreshToken");

        // Logout with refreshToken
        String logoutJson = String.format("""
            {
                "refreshToken": "%s"
            }
            """, refreshToken);

        mockMvc.perform(post("/api/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(logoutJson))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("Logged out successfully"));

        // Attempting to refresh after logout must fail
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(logoutJson))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void testPasswordResetRevokesAllExistingRefreshTokens() throws Exception {
        User user = new User("Mona", "mona@example.com", "CUSTOMER");
        user.setPassword(passwordEncoder.encode("OldPassword123!"));
        user.setEmailVerified(true);
        userRepository.save(user);

        // Login to get active refresh token
        String loginJson = """
            {
                "email": "mona@example.com",
                "password": "OldPassword123!"
            }
            """;

        var loginResult = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginJson))
                .andExpect(status().isOk())
                .andReturn();

        String activeRefreshToken = JsonPath.read(loginResult.getResponse().getContentAsString(), "$.refreshToken");

        // Request forgot password
        String forgotJson = """
            {
                "email": "mona@example.com"
            }
            """;

        var forgotResult = mockMvc.perform(post("/api/auth/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(forgotJson))
                .andExpect(status().isOk())
                .andReturn();

        String resetToken = JsonPath.read(forgotResult.getResponse().getContentAsString(), "$.resetToken");

        // Complete password reset
        String resetJson = String.format("""
            {
                "token": "%s",
                "newPassword": "NewStrongPassword456!"
            }
            """, resetToken);

        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(resetJson))
                .andExpect(status().isOk());

        // Active refresh token must now be REVOKED (session terminated everywhere)
        String refreshJson = String.format("""
            {
                "refreshToken": "%s"
            }
            """, activeRefreshToken);

        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(refreshJson))
                .andExpect(status().isUnauthorized());
    }

    // -------------------------------------------------------------
    // 2. TOKEN STORAGE: HASHED, SINGLE-USE, EXPIRING TOKENS
    // -------------------------------------------------------------
    @Test
    void testVerificationAndResetTokensAreSingleUse() throws Exception {
        // Register user
        String registerJson = """
            {
                "name": "Eve",
                "email": "eve@example.com",
                "password": "Password123!"
            }
            """;

        var regResult = mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(registerJson))
                .andExpect(status().isCreated())
                .andReturn();

        String rawVerifyToken = JsonPath.read(regResult.getResponse().getContentAsString(), "$.verificationToken");

        // First verification succeeds
        mockMvc.perform(get("/api/auth/verify-email")
                        .param("token", rawVerifyToken))
                .andExpect(status().isOk());

        // Second verification with the same token MUST FAIL (single-use)
        mockMvc.perform(get("/api/auth/verify-email")
                        .param("token", rawVerifyToken))
                .andExpect(status().isBadRequest());

        // Request password reset
        String forgotJson = """
            {
                "email": "eve@example.com"
            }
            """;

        var forgotResult = mockMvc.perform(post("/api/auth/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(forgotJson))
                .andExpect(status().isOk())
                .andReturn();

        String rawResetToken = JsonPath.read(forgotResult.getResponse().getContentAsString(), "$.resetToken");

        // First reset succeeds
        String resetJson = String.format("""
            {
                "token": "%s",
                "newPassword": "NewPassword789!"
            }
            """, rawResetToken);

        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(resetJson))
                .andExpect(status().isOk());

        // Second reset with the same token MUST FAIL (single-use)
        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(resetJson))
                .andExpect(status().isBadRequest());
    }

    // -------------------------------------------------------------
    // 3. DUAL RATE-LIMIT KEYS: IP & ACCOUNT EMAIL
    // -------------------------------------------------------------
    @Test
    void testRateLimitByEmailBlocksDistributedBruteForce() throws Exception {
        User user = new User("Frank", "frank@example.com", "CUSTOMER");
        user.setPassword(passwordEncoder.encode("SecretPassword123!"));
        user.setEmailVerified(true);
        userRepository.save(user);

        String badLoginJson = """
            {
                "email": "frank@example.com",
                "password": "WrongPassword!"
            }
            """;

        // 5 attempts from different IPs for the same target email
        for (int i = 1; i <= 5; i++) {
            final String ip = "192.168.1." + i;
            mockMvc.perform(post("/api/auth/login")
                            .with(req -> { req.setRemoteAddr(ip); return req; })
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(badLoginJson))
                    .andExpect(status().isUnauthorized());
        }

        // 6th attempt targeting frank@example.com from a new IP should be blocked by email rate limit (429)
        mockMvc.perform(post("/api/auth/login")
                        .with(req -> { req.setRemoteAddr("192.168.1.99"); return req; })
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(badLoginJson))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.message").value("Too many login attempts for this account. Please wait a minute before retrying."));
    }

    @Test
    void testRateLimitByIpBlocksSingleSourceAttacks() throws Exception {
        // 10 attempts from the same IP targeting different emails
        for (int i = 1; i <= 10; i++) {
            String loginJson = String.format("""
                {
                    "email": "target%d@example.com",
                    "password": "WrongPassword!"
                }
                """, i);

            mockMvc.perform(post("/api/auth/login")
                            .with(req -> { req.setRemoteAddr("10.0.0.1"); return req; })
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(loginJson))
                    .andExpect(status().isUnauthorized());
        }

        // 11th attempt from same IP should be blocked by IP rate limit (429)
        String loginJson = """
            {
                "email": "target11@example.com",
                "password": "WrongPassword!"
            }
            """;

        mockMvc.perform(post("/api/auth/login")
                        .with(req -> { req.setRemoteAddr("10.0.0.1"); return req; })
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginJson))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.message").value("Too many failed or rapid login attempts from this network. Please wait a minute before retrying."));
    }

    @Test
    void testSpoofedXForwardedForCannotDodgeIpRateLimit() throws Exception {
        // Attacker from single remoteAddr 203.0.113.50 sends spoofed X-Forwarded-For headers
        for (int i = 1; i <= 10; i++) {
            String loginJson = String.format("""
                {
                    "email": "spoof_victim%d@example.com",
                    "password": "WrongPassword!"
                }
                """, i);

            mockMvc.perform(post("/api/auth/login")
                            .with(req -> { req.setRemoteAddr("203.0.113.50"); return req; })
                            .header("X-Forwarded-For", "198.51.100." + i)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(loginJson))
                    .andExpect(status().isUnauthorized());
        }

        // 11th attempt rotating X-Forwarded-For must still be blocked because remoteAddr is 203.0.113.50
        String loginJson = """
            {
                "email": "spoof_victim11@example.com",
                "password": "WrongPassword!"
            }
            """;

        mockMvc.perform(post("/api/auth/login")
                        .with(req -> { req.setRemoteAddr("203.0.113.50"); return req; })
                        .header("X-Forwarded-For", "198.51.100.99")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginJson))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.message").value("Too many failed or rapid login attempts from this network. Please wait a minute before retrying."));
    }

    @Test
    void testForgotPasswordRateLimiting() throws Exception {
        User user = new User("Sam", "sam@example.com", "CUSTOMER");
        user.setEmailVerified(true);
        userRepository.save(user);

        String forgotJson = """
            {
                "email": "sam@example.com"
            }
            """;

        // 3 requests allowed per minute per email
        for (int i = 0; i < 3; i++) {
            mockMvc.perform(post("/api/auth/forgot-password")
                            .header("X-Forwarded-For", "10.10.10." + i)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(forgotJson))
                    .andExpect(status().isOk());
        }

        // 4th request must be throttled with 429
        mockMvc.perform(post("/api/auth/forgot-password")
                        .header("X-Forwarded-For", "10.10.10.99")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(forgotJson))
                .andExpect(status().isTooManyRequests());
    }

    // -------------------------------------------------------------
    // 4. STRIPE WEBHOOK IDEMPOTENCY & REPLAY PROTECTION
    // -------------------------------------------------------------
    @Test
    void testStripeWebhookIdempotencyPreventsReplayProcessing() throws Exception {
        String testWebhookSecret = "whsec_test_secret_key_1234567890";
        ReflectionTestUtils.setField(paymentService, "webhookSecret", testWebhookSecret);

        // Setup Customer & Order
        Customer customer = new Customer();
        customer.setName("Grace");
        customer.setEmail("grace@example.com");
        customerRepository.save(customer);

        Order order = new Order();
        order.setCustomer(customer);
        order.setTotalAmount(75.0);
        order.setStatus("PLACED");
        order.setOrderDate(LocalDateTime.now());
        orderRepository.save(order);

        Payment payment = new Payment();
        payment.setOrder(order);
        payment.setAmount(75.0);
        payment.setCurrency("inr");
        payment.setMethod("STRIPE");
        payment.setStatus("PENDING");
        payment.setTransactionId("pi_test_replay_999");
        paymentRepository.save(payment);

        String eventId = "evt_test_replay_event_abc123";
        String payload = String.format("""
            {
              "id": "%s",
              "object": "event",
              "api_version": "%s",
              "type": "payment_intent.succeeded",
              "data": {
                "object": {
                  "id": "pi_test_replay_999",
                  "object": "payment_intent",
                  "amount": 7500,
                  "currency": "inr",
                  "status": "succeeded",
                  "metadata": {
                    "orderId": "%d"
                  }
                }
              }
            }
            """, eventId, com.stripe.Stripe.API_VERSION, order.getOrderId());

        long timestamp = System.currentTimeMillis() / 1000L;
        String signedPayload = timestamp + "." + payload;
        String signature = computeHmacSha256(testWebhookSecret, signedPayload);
        String sigHeader = "t=" + timestamp + ",v1=" + signature;

        // 1. First webhook execution -> should transition order to CONFIRMED and payment to SUCCESS
        mockMvc.perform(post("/payment/webhook")
                        .header("Stripe-Signature", sigHeader)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk());

        Order updatedOrder = orderRepository.findById(order.getOrderId()).orElseThrow();
        assertEquals("PLACED", updatedOrder.getStatus());
        assertEquals(PaymentStatus.PAID, updatedOrder.getPaymentStatus());

        Payment updatedPayment = paymentRepository.findByTransactionId("pi_test_replay_999").orElseThrow();
        assertEquals("SUCCESS", updatedPayment.getStatus());

        assertTrue(processedWebhookEventRepository.existsById(eventId));

        // 2. Replay identical webhook -> must return 200 OK without re-executing
        mockMvc.perform(post("/payment/webhook")
                        .header("Stripe-Signature", sigHeader)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk());

        // Still exactly 1 processed event entry in DB
        assertEquals(1, processedWebhookEventRepository.count());
    }

    @Test
    void testClientSuppliedAmountIsIgnoredWhenCreatingPaymentIntent() throws Exception {
        User user = new User("Dave", "dave@example.com", "CUSTOMER");
        user.setPassword(passwordEncoder.encode("Password123!"));
        user.setEmailVerified(true);
        userRepository.save(user);

        Customer customer = new Customer();
        customer.setName("Dave");
        customer.setEmail("dave@example.com");
        customer = customerRepository.save(customer);

        Order order = new Order();
        order.setCustomer(customer);
        order.setTotalAmount(250.0);
        order.setStatus("PLACED");
        order.setOrderDate(LocalDateTime.now());
        order = orderRepository.save(order);

        String userToken = "Bearer " + jwtService.generateToken(user.getEmail(), "CUSTOMER");

        java.util.concurrent.atomic.AtomicReference<com.stripe.param.PaymentIntentCreateParams> capturedParams = new java.util.concurrent.atomic.AtomicReference<>();
        com.stripe.model.PaymentIntent dummyIntent = org.mockito.Mockito.mock(com.stripe.model.PaymentIntent.class);
        org.mockito.Mockito.when(dummyIntent.getId()).thenReturn("pi_test_mock_abc");
        org.mockito.Mockito.when(dummyIntent.getClientSecret()).thenReturn("pi_test_mock_abc_secret_123");

        PaymentService testService = new PaymentService(paymentRepository, orderRepository, userRepository, processedWebhookEventRepository) {
            @Override
            public com.stripe.model.PaymentIntent executeStripeCall(com.stripe.param.PaymentIntentCreateParams params, com.stripe.net.RequestOptions requestOptions) {
                capturedParams.set(params);
                return dummyIntent;
            }
        };
        ReflectionTestUtils.setField(testService, "secretKey", "sk_test_mock_12345");

        ReflectionTestUtils.setField(paymentController, "paymentService", testService);

        try {
            // Attacker attempts to pay 1.00 INR instead of 250.00 INR
            String tamperingPayload = String.format("""
                {
                    "orderId": %d,
                    "amount": 1.00
                }
                """, order.getOrderId());

            mockMvc.perform(post("/payment/create")
                            .header("Authorization", userToken)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(tamperingPayload))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.orderId").value(order.getOrderId()))
                    .andExpect(jsonPath("$.amount").value(250.0))
                    .andExpect(jsonPath("$.paymentIntentId").value("pi_test_mock_abc"))
                    .andExpect(jsonPath("$.clientSecret").value("pi_test_mock_abc_secret_123"));

            // 1. Verify that Stripe was requested to charge exactly 25000 cents (250.00 * 100), NOT 100 cents
            assertNotNull(capturedParams.get());
            assertEquals(25000L, capturedParams.get().getAmount());
            assertEquals("inr", capturedParams.get().getCurrency());

            // 2. Verify that database Payment entity has the authentic order total, NOT the tampered amount
            Payment savedPayment = paymentRepository.findByTransactionId("pi_test_mock_abc").orElseThrow();
            assertEquals(250.0, savedPayment.getAmount());
            assertEquals("PENDING", savedPayment.getStatus());
        } finally {
            ReflectionTestUtils.setField(paymentController, "paymentService", paymentService);
        }
    }

    @Test
    void testResendVerificationRequiresAuth() throws Exception {
        mockMvc.perform(post("/api/auth/resend-verification")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void testResendVerificationRotatesTokenAndInvalidatesOld() throws Exception {
        User user = new User("Alice", "alice_resend@example.com", "CUSTOMER");
        user.setPassword(passwordEncoder.encode("Password123!"));
        user.setEmailVerified(false);
        userRepository.save(user);

        String userToken = "Bearer " + jwtService.generateToken("alice_resend@example.com", "CUSTOMER", user.getUserId(), "Alice");

        // 1. Resend verification token
        String resendResult = mockMvc.perform(post("/api/auth/resend-verification")
                        .header("Authorization", userToken)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.emailVerified").value(false))
                .andExpect(jsonPath("$.verificationToken").exists())
                .andReturn().getResponse().getContentAsString();

        String rawToken = JsonPath.read(resendResult, "$.verificationToken");

        // 2. Resend again -> should invalidate first token
        String resendResult2 = mockMvc.perform(post("/api/auth/resend-verification")
                        .header("Authorization", userToken)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.verificationToken").exists())
                .andReturn().getResponse().getContentAsString();

        String rawToken2 = JsonPath.read(resendResult2, "$.verificationToken");
        assertNotEquals(rawToken, rawToken2);

        // 3. Old token should now fail
        mockMvc.perform(get("/api/auth/verify-email").param("token", rawToken))
                .andExpect(status().isBadRequest());

        // 4. New token succeeds
        mockMvc.perform(get("/api/auth/verify-email").param("token", rawToken2))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("Email verified successfully. You can now place orders."));

        User verifiedUser = userRepository.findByEmail("alice_resend@example.com").orElseThrow();
        assertTrue(verifiedUser.getEmailVerified());

        // 5. Calling resend after verification returns no-op
        mockMvc.perform(post("/api/auth/resend-verification")
                        .header("Authorization", userToken)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.emailVerified").value(true))
                .andExpect(jsonPath("$.message").value("Email is already verified"));
    }

    @Test
    void testResendVerificationRateLimiting() throws Exception {
        User user = new User("Bob", "bob_resend@example.com", "CUSTOMER");
        user.setPassword(passwordEncoder.encode("Password123!"));
        user.setEmailVerified(false);
        userRepository.save(user);

        String userToken = "Bearer " + jwtService.generateToken("bob_resend@example.com", "CUSTOMER", user.getUserId(), "Bob");

        // First 3 should succeed (limit is 3/min per email)
        for (int i = 0; i < 3; i++) {
            mockMvc.perform(post("/api/auth/resend-verification")
                            .header("Authorization", userToken)
                            .contentType(MediaType.APPLICATION_JSON))
                    .andExpect(status().isOk());
        }

        // 4th request should be throttled
        mockMvc.perform(post("/api/auth/resend-verification")
                        .header("Authorization", userToken)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.status").value(429));
    }

    @Test
    void testReplayAt5sSucceedsOnceAndConsumesGrace() throws Exception {
        Instant baseTime = Instant.parse("2026-10-06T12:00:00Z");
        authenticationService.setClock(Clock.fixed(baseTime, ZoneId.of("UTC")));

        User user = new User("GraceOne", "graceone@example.com", "CUSTOMER");
        user.setPassword(passwordEncoder.encode("Password123!"));
        user.setEmailVerified(true);
        userRepository.save(user);

        // Login to get tokens
        String loginJson = """
            {
                "email": "graceone@example.com",
                "password": "Password123!"
            }
            """;
        String loginResult = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginJson))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String rt1 = JsonPath.read(loginResult, "$.refreshToken");

        // Rotate rt1 at T0 -> rt2
        String refreshPayload1 = String.format("{\"refreshToken\":\"%s\"}", rt1);
        String refreshResult = mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(refreshPayload1))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String rt2 = JsonPath.read(refreshResult, "$.refreshToken");
        assertNotEquals(rt1, rt2);

        // Advance time by 5 seconds (within 15s grace window)
        authenticationService.setClock(Clock.fixed(baseTime.plusSeconds(5), ZoneId.of("UTC")));

        // First replay of rt1 within 5s -> succeeds and mints rt3, consuming grace
        String retryResult = mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(refreshPayload1))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String rt3 = JsonPath.read(retryResult, "$.refreshToken");
        assertNotNull(rt3);
        assertNotEquals(rt2, rt3);

        // Advance time to 6 seconds. Replay rt1 a second time -> grace was consumed, revokes family!
        authenticationService.setClock(Clock.fixed(baseTime.plusSeconds(6), ZoneId.of("UTC")));
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(refreshPayload1))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("Refresh token reuse detected")));

        // Verify family was revoked: even rt3 is dead!
        String refreshPayload3 = String.format("{\"refreshToken\":\"%s\"}", rt3);
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(refreshPayload3))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void testSecondReplayWithinGraceRevokesFamily() throws Exception {
        Instant baseTime = Instant.parse("2026-10-06T12:00:00Z");
        authenticationService.setClock(Clock.fixed(baseTime, ZoneId.of("UTC")));

        User user = new User("GraceTwo", "gracetwo@example.com", "CUSTOMER");
        user.setPassword(passwordEncoder.encode("Password123!"));
        user.setEmailVerified(true);
        userRepository.save(user);

        String loginResult = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"gracetwo@example.com\",\"password\":\"Password123!\"}"))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String rt1 = JsonPath.read(loginResult, "$.refreshToken");

        // Rotate rt1 -> rt2
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(String.format("{\"refreshToken\":\"%s\"}", rt1)))
                .andExpect(status().isOk());

        // Advance 2s: Replay 1 succeeds
        authenticationService.setClock(Clock.fixed(baseTime.plusSeconds(2), ZoneId.of("UTC")));
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(String.format("{\"refreshToken\":\"%s\"}", rt1)))
                .andExpect(status().isOk());

        // Advance 4s (still within 15s): Replay 2 is rejected because grace was consumed!
        authenticationService.setClock(Clock.fixed(baseTime.plusSeconds(4), ZoneId.of("UTC")));
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(String.format("{\"refreshToken\":\"%s\"}", rt1)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("Refresh token reuse detected")));
    }

    @Test
    void testReplayAt16sRevokesFamily() throws Exception {
        Instant baseTime = Instant.parse("2026-10-06T12:00:00Z");
        authenticationService.setClock(Clock.fixed(baseTime, ZoneId.of("UTC")));

        User user = new User("Grace16", "grace16@example.com", "CUSTOMER");
        user.setPassword(passwordEncoder.encode("Password123!"));
        user.setEmailVerified(true);
        userRepository.save(user);

        String loginResult = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"grace16@example.com\",\"password\":\"Password123!\"}"))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String rt1 = JsonPath.read(loginResult, "$.refreshToken");

        // Rotate rt1 -> rt2
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(String.format("{\"refreshToken\":\"%s\"}", rt1)))
                .andExpect(status().isOk());

        // Advance time by 16 seconds (past 15s grace window)
        authenticationService.setClock(Clock.fixed(baseTime.plusSeconds(16), ZoneId.of("UTC")));

        // Replaying rt1 at 16s triggers family reuse detection immediately!
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(String.format("{\"refreshToken\":\"%s\"}", rt1)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("Refresh token reuse detected")));
    }

    @Test
    void testOldSuccessorDeadAfterGraceMint() throws Exception {
        Instant baseTime = Instant.parse("2026-10-06T12:00:00Z");
        authenticationService.setClock(Clock.fixed(baseTime, ZoneId.of("UTC")));

        User user = new User("GraceDead", "gracedead@example.com", "CUSTOMER");
        user.setPassword(passwordEncoder.encode("Password123!"));
        user.setEmailVerified(true);
        userRepository.save(user);

        String loginResult = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"gracedead@example.com\",\"password\":\"Password123!\"}"))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String rt1 = JsonPath.read(loginResult, "$.refreshToken");

        // Rotate rt1 -> rt2
        String refreshResult = mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(String.format("{\"refreshToken\":\"%s\"}", rt1)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String rt2 = JsonPath.read(refreshResult, "$.refreshToken");

        // Advance time by 3s: Replay rt1 -> mints rt3
        authenticationService.setClock(Clock.fixed(baseTime.plusSeconds(3), ZoneId.of("UTC")));
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(String.format("{\"refreshToken\":\"%s\"}", rt1)))
                .andExpect(status().isOk());

        // Now attempt to use rt2 -> rt2 was revoked when rt3 was minted, so using rt2 is rejected!
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(String.format("{\"refreshToken\":\"%s\"}", rt2)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void testConcurrentReplaysYieldExactlyOneSuccess() throws Exception {
        User user = new User("GraceConc", "graceconc@example.com", "CUSTOMER");
        user.setPassword(passwordEncoder.encode("Password123!"));
        user.setEmailVerified(true);
        userRepository.save(user);

        String loginResult = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"graceconc@example.com\",\"password\":\"Password123!\"}"))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String rt1 = JsonPath.read(loginResult, "$.refreshToken");

        // Rotate rt1 -> rt2
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(String.format("{\"refreshToken\":\"%s\"}", rt1)))
                .andExpect(status().isOk());

        // Now launch 2 concurrent replays of rt1
        ExecutorService executor = Executors.newFixedThreadPool(2);
        CountDownLatch startLatch = new CountDownLatch(1);
        CountDownLatch finishLatch = new CountDownLatch(2);
        AtomicInteger successCount = new AtomicInteger(0);
        AtomicInteger unauthorizedCount = new AtomicInteger(0);

        for (int i = 0; i < 2; i++) {
            executor.submit(() -> {
                try {
                    startLatch.await();
                    var mvcResult = mockMvc.perform(post("/api/auth/refresh")
                                    .contentType(MediaType.APPLICATION_JSON)
                                    .content(String.format("{\"refreshToken\":\"%s\"}", rt1)))
                            .andReturn();
                    int status = mvcResult.getResponse().getStatus();
                    if (status == 200) {
                        successCount.incrementAndGet();
                    } else if (status == 401) {
                        unauthorizedCount.incrementAndGet();
                    }
                } catch (Exception ignored) {
                } finally {
                    finishLatch.countDown();
                }
            });
        }

        startLatch.countDown();
        assertTrue(finishLatch.await(5, TimeUnit.SECONDS));
        executor.shutdown();

        // Exactly one concurrent request succeeded and consumed the grace window; the other was rejected!
        assertEquals(1, successCount.get(), "Expected exactly 1 success among concurrent replays");
        assertEquals(1, unauthorizedCount.get(), "Expected exactly 1 failure among concurrent replays");
    }

    @Test
    void testCheckoutUnverifiedEmailReturnsEmailNotVerifiedCode() throws Exception {
        User user = new User("Unverified", "unverified@example.com", "CUSTOMER");
        user.setPassword(passwordEncoder.encode("Password123!"));
        user.setEmailVerified(false);
        userRepository.save(user);

        String userToken = "Bearer " + jwtService.generateToken("unverified@example.com", "CUSTOMER", user.getUserId(), "Unverified");

        mockMvc.perform(post("/orders/checkout")
                        .header("Authorization", userToken)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("EMAIL_NOT_VERIFIED"))
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("verify your email")));
    }

    @Test
    void testPaymentIntentCreationIdempotentPerOrder() throws Exception {
        User user = new User("Idem", "idem@example.com", "CUSTOMER");
        user.setPassword(passwordEncoder.encode("Password123!"));
        user.setEmailVerified(true);
        userRepository.save(user);

        Customer customer = new Customer();
        customer.setName("Idem");
        customer.setEmail("idem@example.com");
        customerRepository.save(customer);

        Order order = new Order();
        order.setCustomer(customer);
        order.setStatus("PLACED");
        order.setTotalAmount(150.0);
        orderRepository.save(order);

        String userToken = "Bearer " + jwtService.generateToken("idem@example.com", "CUSTOMER", user.getUserId(), "Idem");

        com.stripe.model.PaymentIntent dummyIntent = new com.stripe.model.PaymentIntent();
        dummyIntent.setId("pi_idem_123");
        dummyIntent.setClientSecret("pi_idem_123_secret");
        dummyIntent.setStatus("requires_payment_method");

        java.util.concurrent.atomic.AtomicInteger stripeCreateCalls = new java.util.concurrent.atomic.AtomicInteger(0);
        java.util.concurrent.atomic.AtomicInteger stripeRetrieveCalls = new java.util.concurrent.atomic.AtomicInteger(0);

        PaymentService testService = new PaymentService(paymentRepository, orderRepository, userRepository, processedWebhookEventRepository) {
            @Override
            public com.stripe.model.PaymentIntent executeStripeCall(com.stripe.param.PaymentIntentCreateParams params, com.stripe.net.RequestOptions requestOptions) {
                stripeCreateCalls.incrementAndGet();
                return dummyIntent;
            }

            @Override
            public com.stripe.model.PaymentIntent retrieveStripeIntent(String paymentIntentId) {
                stripeRetrieveCalls.incrementAndGet();
                return dummyIntent;
            }
        };
        ReflectionTestUtils.setField(testService, "secretKey", "sk_test_mock_12345");
        ReflectionTestUtils.setField(paymentController, "paymentService", testService);

        try {
            String payload = String.format("""
                {
                    "orderId": %d
                }
                """, order.getOrderId());

            // First call -> creates PaymentIntent
            mockMvc.perform(post("/payment/create")
                            .header("Authorization", userToken)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(payload))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.paymentIntentId").value("pi_idem_123"))
                    .andExpect(jsonPath("$.clientSecret").value("pi_idem_123_secret"));

            assertEquals(1, stripeCreateCalls.get());
            assertEquals(0, stripeRetrieveCalls.get());

            // Second call -> reuses existing PaymentIntent without calling create again
            mockMvc.perform(post("/payment/create")
                            .header("Authorization", userToken)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(payload))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.paymentIntentId").value("pi_idem_123"))
                    .andExpect(jsonPath("$.clientSecret").value("pi_idem_123_secret"));

            // executeStripeCall should still be 1 (never called twice!), retrieve was called once
            assertEquals(1, stripeCreateCalls.get());
            assertEquals(1, stripeRetrieveCalls.get());
        } finally {
            ReflectionTestUtils.setField(paymentController, "paymentService", paymentService);
        }
    }

    @Test
    void testLatePaymentFailedCannotDowngradePaidOrder() throws Exception {
        String testWebhookSecret = "whsec_test_secret_1234567890abcdef";
        ReflectionTestUtils.setField(paymentService, "webhookSecret", testWebhookSecret);

        User user = new User("PaidLate", "paidlate@example.com", "CUSTOMER");
        user.setEmailVerified(true);
        userRepository.save(user);

        Customer customer = new Customer();
        customer.setName("PaidLate");
        customer.setEmail("paidlate@example.com");
        customerRepository.save(customer);

        Order order = new Order();
        order.setCustomer(customer);
        order.setStatus("PLACED");
        order.setPaymentStatus(PaymentStatus.PAID);
        order.setTotalAmount(100.0);
        orderRepository.save(order);

        Payment payment = new Payment();
        payment.setOrder(order);
        payment.setStatus("SUCCESS");
        payment.setAmount(100.0);
        payment.setCurrency("inr");
        payment.setTransactionId("pi_late_fail_123");
        paymentRepository.save(payment);

        long timestamp = Instant.now().getEpochSecond();
        String eventId = "evt_late_fail_123";
        String payload = String.format("""
            {
                "id": "%s",
                "object": "event",
                "type": "payment_intent.payment_failed",
                "data": {
                    "object": {
                        "id": "pi_late_fail_123",
                        "object": "payment_intent",
                        "amount": 10000,
                        "currency": "inr",
                        "metadata": {
                            "orderId": "%d"
                        }
                    }
                }
            }
            """, eventId, order.getOrderId());

        String signedPayload = timestamp + "." + payload;
        String signature = computeHmacSha256(testWebhookSecret, signedPayload);
        String sigHeader = "t=" + timestamp + ",v1=" + signature;

        mockMvc.perform(post("/payment/webhook")
                        .header("Stripe-Signature", sigHeader)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk());

        // Order MUST remain PAID! Terminal state cannot be downgraded by late failure.
        Order updatedOrder = orderRepository.findById(order.getOrderId()).orElseThrow();
        assertEquals(PaymentStatus.PAID, updatedOrder.getPaymentStatus());
    }

    @Test
    void testWebhookRejectsAmountOrOrderIdMismatch() throws Exception {
        String testWebhookSecret = "whsec_test_secret_1234567890abcdef";
        ReflectionTestUtils.setField(paymentService, "webhookSecret", testWebhookSecret);

        User user = new User("Mismatch", "mismatch@example.com", "CUSTOMER");
        user.setEmailVerified(true);
        userRepository.save(user);

        Customer customer = new Customer();
        customer.setName("Mismatch");
        customer.setEmail("mismatch@example.com");
        customerRepository.save(customer);

        Order order = new Order();
        order.setCustomer(customer);
        order.setStatus("PLACED");
        order.setPaymentStatus(PaymentStatus.PENDING);
        order.setTotalAmount(200.0); // 200.0 INR = 20000 cents
        orderRepository.save(order);

        // 1. Send webhook with tampered amount (e.g. 5000 cents != 20000 cents)
        long timestamp = Instant.now().getEpochSecond();
        String payloadTamperedAmount = String.format("""
            {
                "id": "evt_tampered_amt",
                "object": "event",
                "type": "payment_intent.succeeded",
                "data": {
                    "object": {
                        "id": "pi_tampered_amt",
                        "object": "payment_intent",
                        "amount": 5000,
                        "currency": "inr",
                        "metadata": {
                            "orderId": "%d"
                        }
                    }
                }
            }
            """, order.getOrderId());

        String sigTampered = "t=" + timestamp + ",v1=" + computeHmacSha256(testWebhookSecret, timestamp + "." + payloadTamperedAmount);

        mockMvc.perform(post("/payment/webhook")
                        .header("Stripe-Signature", sigTampered)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payloadTamperedAmount))
                .andExpect(status().isOk());

        // Order remains PENDING because amount mismatched!
        Order orderAfterTampered = orderRepository.findById(order.getOrderId()).orElseThrow();
        assertEquals(PaymentStatus.PENDING, orderAfterTampered.getPaymentStatus());

        // 2. Send webhook with orderId metadata mismatch
        String payloadBadOrderId = """
            {
                "id": "evt_bad_order_id",
                "object": "event",
                "type": "payment_intent.succeeded",
                "data": {
                    "object": {
                        "id": "pi_bad_order_id",
                        "object": "payment_intent",
                        "amount": 20000,
                        "currency": "inr",
                        "metadata": {
                            "orderId": "999999"
                        }
                    }
                }
            }
            """;
        String sigBadOrder = "t=" + timestamp + ",v1=" + computeHmacSha256(testWebhookSecret, timestamp + "." + payloadBadOrderId);

        mockMvc.perform(post("/payment/webhook")
                        .header("Stripe-Signature", sigBadOrder)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payloadBadOrderId))
                .andExpect(status().isOk());

        Order orderAfterBadId = orderRepository.findById(order.getOrderId()).orElseThrow();
        assertEquals(PaymentStatus.PENDING, orderAfterBadId.getPaymentStatus());
    }

    @Test
    void testPaymentRetryResetsFailedToPending() throws Exception {
        User user = new User("RetryUser", "retry@example.com", "CUSTOMER");
        user.setEmailVerified(true);
        userRepository.save(user);

        Customer customer = new Customer();
        customer.setName("RetryUser");
        customer.setEmail("retry@example.com");
        customerRepository.save(customer);

        Order order = new Order();
        order.setCustomer(customer);
        order.setStatus("PLACED");
        order.setPaymentStatus(PaymentStatus.FAILED);
        order.setTotalAmount(120.0);
        orderRepository.save(order);

        String userToken = "Bearer " + jwtService.generateToken("retry@example.com", "CUSTOMER", user.getUserId(), "RetryUser");

        com.stripe.model.PaymentIntent dummyIntent = new com.stripe.model.PaymentIntent();
        dummyIntent.setId("pi_retry_123");
        dummyIntent.setClientSecret("pi_retry_123_secret");
        dummyIntent.setStatus("requires_payment_method");

        PaymentService testService = new PaymentService(paymentRepository, orderRepository, userRepository, processedWebhookEventRepository) {
            @Override
            public com.stripe.model.PaymentIntent executeStripeCall(com.stripe.param.PaymentIntentCreateParams params, com.stripe.net.RequestOptions requestOptions) {
                return dummyIntent;
            }
        };
        ReflectionTestUtils.setField(testService, "secretKey", "sk_test_mock_12345");
        ReflectionTestUtils.setField(paymentController, "paymentService", testService);

        try {
            String payload = String.format("{\"orderId\": %d}", order.getOrderId());
            mockMvc.perform(post("/payment/create")
                            .header("Authorization", userToken)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(payload))
                    .andExpect(status().isOk());

            // Order paymentStatus must be reset from FAILED back to PENDING!
            Order updatedOrder = orderRepository.findById(order.getOrderId()).orElseThrow();
            assertEquals(PaymentStatus.PENDING, updatedOrder.getPaymentStatus());
        } finally {
            ReflectionTestUtils.setField(paymentController, "paymentService", paymentService);
        }
    }

    private String computeHmacSha256(String key, String data) throws Exception {
        Mac sha256Hmac = Mac.getInstance("HmacSHA256");
        SecretKeySpec secretKey = new SecretKeySpec(key.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
        sha256Hmac.init(secretKey);
        byte[] hash = sha256Hmac.doFinal(data.getBytes(StandardCharsets.UTF_8));
        StringBuilder result = new StringBuilder();
        for (byte b : hash) {
            result.append(String.format("%02x", b));
        }
        return result.toString();
    }
}
