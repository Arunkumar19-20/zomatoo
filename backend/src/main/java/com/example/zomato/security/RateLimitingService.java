package com.example.zomato.security;

import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import io.github.bucket4j.Refill;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Rate Limiting Service using Token Bucket algorithm (Bucket4j).
 *
 * NOTE FOR PRODUCTION DEPLOYMENT:
 * This implementation uses in-memory ConcurrentHashMaps suitable for single-instance
 * deployments and testing. For multi-instance horizontal scaling, swap this with
 * Bucket4j Redis extension (`bucket4j-redis`) backed by Redis/Valkey or delegate rate
 * limiting to an API gateway (e.g. AWS API Gateway, Cloudflare, Envoy, or Kong).
 */
@Service
public class RateLimitingService {

    private final Map<String, Bucket> loginIpBuckets = new ConcurrentHashMap<>();
    private final Map<String, Bucket> loginEmailBuckets = new ConcurrentHashMap<>();
    private final Map<String, Bucket> registerBuckets = new ConcurrentHashMap<>();
    private final Map<String, Bucket> forgotPasswordIpBuckets = new ConcurrentHashMap<>();
    private final Map<String, Bucket> forgotPasswordEmailBuckets = new ConcurrentHashMap<>();
    private final Map<String, Bucket> resendVerificationIpBuckets = new ConcurrentHashMap<>();
    private final Map<String, Bucket> resendVerificationEmailBuckets = new ConcurrentHashMap<>();
    private final Map<String, Bucket> refreshBuckets = new ConcurrentHashMap<>();

    private Bucket createLoginIpBucket() {
        // 10 attempts per minute per IP
        Refill refill = Refill.greedy(10, Duration.ofMinutes(1));
        Bandwidth limit = Bandwidth.classic(10, refill);
        return Bucket.builder().addLimit(limit).build();
    }

    private Bucket createLoginEmailBucket() {
        // 5 attempts per minute per email (prevents distributed credential stuffing)
        Refill refill = Refill.greedy(5, Duration.ofMinutes(1));
        Bandwidth limit = Bandwidth.classic(5, refill);
        return Bucket.builder().addLimit(limit).build();
    }

    private Bucket createRegisterBucket() {
        // 10 registration attempts per minute per IP
        Refill refill = Refill.greedy(10, Duration.ofMinutes(1));
        Bandwidth limit = Bandwidth.classic(10, refill);
        return Bucket.builder().addLimit(limit).build();
    }

    private Bucket createForgotPasswordIpBucket() {
        // 5 password reset requests per minute per IP
        Refill refill = Refill.greedy(5, Duration.ofMinutes(1));
        Bandwidth limit = Bandwidth.classic(5, refill);
        return Bucket.builder().addLimit(limit).build();
    }

    private Bucket createForgotPasswordEmailBucket() {
        // 3 password reset requests per minute per target email
        Refill refill = Refill.greedy(3, Duration.ofMinutes(1));
        Bandwidth limit = Bandwidth.classic(3, refill);
        return Bucket.builder().addLimit(limit).build();
    }

    private Bucket createResendVerificationIpBucket() {
        // 5 resend verification requests per minute per IP
        Refill refill = Refill.greedy(5, Duration.ofMinutes(1));
        Bandwidth limit = Bandwidth.classic(5, refill);
        return Bucket.builder().addLimit(limit).build();
    }

    private Bucket createResendVerificationEmailBucket() {
        // 3 resend verification requests per minute per target account
        Refill refill = Refill.greedy(3, Duration.ofMinutes(1));
        Bandwidth limit = Bandwidth.classic(3, refill);
        return Bucket.builder().addLimit(limit).build();
    }

    private Bucket createRefreshBucket() {
        // 30 token refreshes per minute per IP
        Refill refill = Refill.greedy(30, Duration.ofMinutes(1));
        Bandwidth limit = Bandwidth.classic(30, refill);
        return Bucket.builder().addLimit(limit).build();
    }

    public boolean tryConsumeLoginByIp(String ip) {
        if (ip == null || ip.isBlank()) return true;
        Bucket bucket = loginIpBuckets.computeIfAbsent(ip, k -> createLoginIpBucket());
        return bucket.tryConsume(1);
    }

    public boolean tryConsumeLoginByEmail(String email) {
        if (email == null || email.isBlank()) return true;
        String normalized = email.toLowerCase().trim();
        Bucket bucket = loginEmailBuckets.computeIfAbsent(normalized, k -> createLoginEmailBucket());
        return bucket.tryConsume(1);
    }

    public boolean tryConsumeRegister(String ip) {
        if (ip == null || ip.isBlank()) return true;
        Bucket bucket = registerBuckets.computeIfAbsent(ip, k -> createRegisterBucket());
        return bucket.tryConsume(1);
    }

    public boolean tryConsumeForgotPasswordByIp(String ip) {
        if (ip == null || ip.isBlank()) return true;
        Bucket bucket = forgotPasswordIpBuckets.computeIfAbsent(ip, k -> createForgotPasswordIpBucket());
        return bucket.tryConsume(1);
    }

    public boolean tryConsumeForgotPasswordByEmail(String email) {
        if (email == null || email.isBlank()) return true;
        String normalized = email.toLowerCase().trim();
        Bucket bucket = forgotPasswordEmailBuckets.computeIfAbsent(normalized, k -> createForgotPasswordEmailBucket());
        return bucket.tryConsume(1);
    }

    public boolean tryConsumeResendVerificationByIp(String ip) {
        if (ip == null || ip.isBlank()) return true;
        Bucket bucket = resendVerificationIpBuckets.computeIfAbsent(ip, k -> createResendVerificationIpBucket());
        return bucket.tryConsume(1);
    }

    public boolean tryConsumeResendVerificationByEmail(String email) {
        if (email == null || email.isBlank()) return true;
        String normalized = email.toLowerCase().trim();
        Bucket bucket = resendVerificationEmailBuckets.computeIfAbsent(normalized, k -> createResendVerificationEmailBucket());
        return bucket.tryConsume(1);
    }

    public boolean tryConsumeRefresh(String ip) {
        if (ip == null || ip.isBlank()) return true;
        Bucket bucket = refreshBuckets.computeIfAbsent(ip, k -> createRefreshBucket());
        return bucket.tryConsume(1);
    }

    private final Map<String, Bucket> reserveBuckets = new ConcurrentHashMap<>();

    private Bucket createReserveBucket() {
        // 10 drop reservation attempts per minute per user (burst up to 10, refills at 10/min)
        Refill refill = Refill.greedy(10, Duration.ofMinutes(1));
        Bandwidth limit = Bandwidth.classic(10, refill);
        return Bucket.builder().addLimit(limit).build();
    }

    /**
     * Rate limits POST /drops/{id}/reserve requests per user to protect against hoarding bots and spam.
     * Limit: 10 attempts per minute per authenticated user account.
     * Limits & Trade-offs:
     * - Uses in-memory Token Bucket (Bucket4j). Suitable for single-node deployments.
     * - For multi-replica production clusters, rate limiting state should be centralized
     *   via Redis (bucket4j-redis) or an API Gateway (Cloudflare / Kong / Envoy) to prevent
     *   rate-limit bypass across instances.
     */
    public boolean tryConsumeReserve(String email) {
        if (email == null || email.isBlank()) return true;
        String normalized = email.toLowerCase().trim();
        Bucket bucket = reserveBuckets.computeIfAbsent(normalized, k -> createReserveBucket());
        return bucket.tryConsume(1);
    }

    // Backwards-compatible legacy method
    public boolean tryConsumeLogin(String key) {
        return tryConsumeLoginByIp(key);
    }

    public void reset() {
        loginIpBuckets.clear();
        loginEmailBuckets.clear();
        registerBuckets.clear();
        forgotPasswordIpBuckets.clear();
        forgotPasswordEmailBuckets.clear();
        resendVerificationIpBuckets.clear();
        resendVerificationEmailBuckets.clear();
        refreshBuckets.clear();
        reserveBuckets.clear();
    }
}
