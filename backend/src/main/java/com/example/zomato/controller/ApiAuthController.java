package com.example.zomato.controller;

import com.example.zomato.dto.*;
import com.example.zomato.security.RateLimitingService;
import com.example.zomato.services.AuthenticationService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class ApiAuthController {

    private final AuthenticationService authService;
    private final RateLimitingService rateLimitingService;

    public ApiAuthController(AuthenticationService authService, RateLimitingService rateLimitingService) {
        this.authService = authService;
        this.rateLimitingService = rateLimitingService;
    }

    /**
     * Extracts client IP.
     *
     * SECURITY & PROXY TRUST NOTE:
     * Strictly uses request.getRemoteAddr(). When deploying behind a trusted reverse
     * proxy / load balancer, configure 'server.forward-headers-strategy: native'
     * along with 'server.tomcat.remoteip.internal-proxies'. Tomcat's RemoteIpValve
     * will automatically resolve the genuine client IP into request.getRemoteAddr()
     * only when the request originates from a trusted internal proxy IP.
     * Direct untrusted callers sending spoofed X-Forwarded-For headers are ignored,
     * preventing rate limiting bypass.
     */
    private String getClientIp(HttpServletRequest request) {
        return request.getRemoteAddr();
    }

    @PostMapping("/register")
    public ResponseEntity<?> register(@Valid @RequestBody RegisterRequest request, HttpServletRequest httpRequest) {
        String clientIp = getClientIp(httpRequest);
        if (!rateLimitingService.tryConsumeRegister(clientIp)) {
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).body(Map.of(
                    "status", 429,
                    "error", "Too Many Requests",
                    "message", "Rate limit exceeded. Please try again later."
            ));
        }

        Map<String, Object> response = authService.register(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@Valid @RequestBody LoginRequest request, HttpServletRequest httpRequest) {
        String clientIp = getClientIp(httpRequest);

        // Limit by Client IP (10/min)
        if (!rateLimitingService.tryConsumeLoginByIp(clientIp)) {
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).body(Map.of(
                    "status", 429,
                    "error", "Too Many Requests",
                    "message", "Too many failed or rapid login attempts from this network. Please wait a minute before retrying."
            ));
        }

        // Limit by Account Email (5/min) to prevent distributed brute-force against a single account
        if (!rateLimitingService.tryConsumeLoginByEmail(request.getEmail())) {
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).body(Map.of(
                    "status", 429,
                    "error", "Too Many Requests",
                    "message", "Too many login attempts for this account. Please wait a minute before retrying."
            ));
        }

        AuthResponse response = authService.login(request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/refresh")
    public ResponseEntity<?> refreshToken(@Valid @RequestBody RefreshTokenRequest request, HttpServletRequest httpRequest) {
        String clientIp = getClientIp(httpRequest);
        if (!rateLimitingService.tryConsumeRefresh(clientIp)) {
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).body(Map.of(
                    "status", 429,
                    "error", "Too Many Requests",
                    "message", "Rate limit exceeded for token refresh. Please try again later."
            ));
        }

        AuthResponse response = authService.refreshToken(request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/logout")
    public ResponseEntity<?> logout(@RequestBody(required = false) RefreshTokenRequest request,
                                    Authentication authentication) {
        String userEmail = authentication != null ? authentication.getName() : null;
        String refreshToken = request != null ? request.getRefreshToken() : null;
        Map<String, Object> response = authService.logout(refreshToken, userEmail);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/resend-verification")
    public ResponseEntity<?> resendVerification(Authentication authentication, HttpServletRequest httpRequest) {
        if (authentication == null || authentication.getName() == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of(
                    "status", 401,
                    "error", "Unauthorized",
                    "message", "User must be logged in to resend verification email."
            ));
        }

        String clientIp = getClientIp(httpRequest);
        String userEmail = authentication.getName();

        if (!rateLimitingService.tryConsumeResendVerificationByIp(clientIp) ||
                !rateLimitingService.tryConsumeResendVerificationByEmail(userEmail)) {
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).body(Map.of(
                    "status", 429,
                    "error", "Too Many Requests",
                    "message", "Too many verification requests. Please wait a minute before retrying."
            ));
        }

        Map<String, Object> response = authService.resendVerificationToken(userEmail);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/verify-email")
    public ResponseEntity<?> verifyEmail(@RequestParam String token) {
        Map<String, Object> response = authService.verifyEmail(token);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/forgot-password")
    public ResponseEntity<?> forgotPassword(@Valid @RequestBody ForgotPasswordRequest request, HttpServletRequest httpRequest) {
        String clientIp = getClientIp(httpRequest);
        if (!rateLimitingService.tryConsumeForgotPasswordByIp(clientIp) ||
                !rateLimitingService.tryConsumeForgotPasswordByEmail(request.getEmail())) {
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).body(Map.of(
                    "status", 429,
                    "error", "Too Many Requests",
                    "message", "Too many password reset requests. Please wait a few minutes before trying again."
            ));
        }

        Map<String, Object> response = authService.forgotPassword(request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/reset-password")
    public ResponseEntity<?> resetPassword(@Valid @RequestBody ResetPasswordRequest request) {
        Map<String, Object> response = authService.resetPassword(request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/google")
    public ResponseEntity<?> googleAuth(@Valid @RequestBody GoogleAuthRequest request) {
        AuthResponse response = authService.authenticateGoogleToken(request);
        return ResponseEntity.ok(response);
    }
}
