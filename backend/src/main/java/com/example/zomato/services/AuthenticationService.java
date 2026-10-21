package com.example.zomato.services;

import com.example.zomato.dto.*;
import com.example.zomato.entity.RefreshToken;
import com.example.zomato.entity.User;
import com.example.zomato.repository.RefreshTokenRepository;
import com.example.zomato.repository.UserRepository;
import com.example.zomato.security.JwtService;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.*;

@Service
public class AuthenticationService {

    private static final Logger logger = LoggerFactory.getLogger(AuthenticationService.class);

    private final UserRepository userRepository;
    private final CustomerService customerService;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final RefreshTokenRepository refreshTokenRepository;

    private Clock clock = Clock.systemDefaultZone();

    @Value("${spring.security.oauth2.client.registration.google.client-id:}")
    private String googleClientId;

    public void setClock(Clock clock) {
        this.clock = clock;
    }

    public AuthenticationService(UserRepository userRepository,
                                 CustomerService customerService,
                                 PasswordEncoder passwordEncoder,
                                 JwtService jwtService,
                                 RefreshTokenRepository refreshTokenRepository) {
        this.userRepository = userRepository;
        this.customerService = customerService;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.refreshTokenRepository = refreshTokenRepository;
    }

    public String hashToken(String rawToken) {
        if (rawToken == null) return null;
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(rawToken.getBytes(StandardCharsets.UTF_8));
            StringBuilder hexString = new StringBuilder();
            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) hexString.append('0');
                hexString.append(hex);
            }
            return hexString.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 algorithm not available", e);
        }
    }

    @Transactional
    public String createRefreshTokenForUser(User user) {
        String rawRefreshToken = UUID.randomUUID().toString();
        String hashedToken = hashToken(rawRefreshToken);
        LocalDateTime expiryDate = LocalDateTime.now().plusDays(30);

        RefreshToken refreshToken = new RefreshToken(hashedToken, user, expiryDate);
        refreshTokenRepository.save(refreshToken);
        return rawRefreshToken;
    }

    @Transactional
    public Map<String, Object> register(RegisterRequest request) {
        String email = request.getEmail().toLowerCase().trim();

        Optional<User> existingUserOpt = userRepository.findByEmail(email);
        if (existingUserOpt.isPresent()) {
            User existing = existingUserOpt.get();
            if (existing.getPassword() != null && !existing.getPassword().isBlank()) {
                throw new IllegalArgumentException("An account with this email already exists");
            }
            // User previously logged in via Google OAuth; attach password
            existing.setPassword(passwordEncoder.encode(request.getPassword()));
            if (request.getName() != null && !request.getName().isBlank()) {
                existing.setName(request.getName());
            }
            userRepository.save(existing);
            customerService.getOrCreateCustomer(email, existing.getRole());
            return Map.of(
                    "message", "Account linked with password. You can now log in.",
                    "email", email,
                    "emailVerified", existing.getEmailVerified()
            );
        }

        User user = new User();
        user.setName(request.getName());
        user.setEmail(email);
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setRole("CUSTOMER"); // Strictly default to CUSTOMER
        user.setEmailVerified(false);

        String rawVerificationToken = UUID.randomUUID().toString();
        user.setEmailVerificationToken(hashToken(rawVerificationToken));
        user.setEmailVerificationExpiry(LocalDateTime.now().plusHours(24));
        user.setCreatedAt(LocalDateTime.now());

        userRepository.save(user);

        // Ensure customer record exists
        customerService.getOrCreateCustomer(email, "CUSTOMER");

        logger.info("New user registered: {}. Raw verification token issued.", email);
        logger.info("[DEV] Email verification link for {}: http://localhost:8080/api/auth/verify-email?token={}", email, rawVerificationToken);

        Map<String, Object> response = new HashMap<>();
        response.put("message", "User registered successfully. Please verify your email to place orders.");
        response.put("email", email);
        response.put("role", user.getRole());
        response.put("userId", user.getUserId());
        response.put("verificationToken", rawVerificationToken);
        response.put("emailVerified", false);
        return response;
    }

    @Transactional
    public AuthResponse login(LoginRequest request) {
        String email = request.getEmail().toLowerCase().trim();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new BadCredentialsException("Invalid email or password"));

        if (user.getPassword() == null || user.getPassword().isBlank()) {
            throw new BadCredentialsException("This account was created with Google Sign-In. Please sign in with Google.");
        }

        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            throw new BadCredentialsException("Invalid email or password");
        }

        String role = user.getRole() != null ? user.getRole() : "CUSTOMER";
        String accessToken = jwtService.generateToken(user.getEmail(), role, user.getUserId(), user.getName());
        String refreshToken = createRefreshTokenForUser(user);

        customerService.getOrCreateCustomer(email, role);

        return new AuthResponse(
                accessToken,
                refreshToken,
                jwtService.getExpirationInSeconds(),
                user.getEmail(),
                role,
                user.getName(),
                user.getUserId(),
                user.getEmailVerified()
        );
    }

    @Transactional(noRollbackFor = BadCredentialsException.class)
    public AuthResponse refreshToken(RefreshTokenRequest request) {
        if (request == null || request.getRefreshToken() == null || request.getRefreshToken().isBlank()) {
            throw new BadCredentialsException("Refresh token is required");
        }

        String rawToken = request.getRefreshToken().trim();
        String hashedToken = hashToken(rawToken);

        RefreshToken storedToken = refreshTokenRepository.findByTokenHash(hashedToken)
                .orElseThrow(() -> new BadCredentialsException("Invalid or unrecognized refresh token"));

        if (storedToken.isRevoked()) {
            User user = storedToken.getUser();
            String userEmail = user != null ? user.getEmail() : "unknown";
            LocalDateTime now = LocalDateTime.now(clock);
            if (storedToken.getRotatedAt() != null && storedToken.getRotatedAt().isAfter(now.minusSeconds(15))) {
                // Check if successor was already used/rotated/revoked!
                // If successor has been rotated or revoked, the replay is an attack, not a network retry.
                if (storedToken.getSuccessorTokenHash() != null) {
                    Optional<RefreshToken> successorOpt = refreshTokenRepository.findByTokenHash(storedToken.getSuccessorTokenHash());
                    if (successorOpt.isPresent()) {
                        RefreshToken successor = successorOpt.get();
                        if (successor.isRevoked() || successor.getRotatedAt() != null) {
                            logger.warn("SECURITY ALERT: Successor token has already been rotated/revoked. Replay of ancestor token is an attack. Revoking entire token family.");
                            refreshTokenRepository.revokeAllByUser(user);
                            throw new BadCredentialsException("Refresh token reuse detected. All active sessions have been invalidated for security. Please log in again.");
                        }
                    }
                }

                // Consume grace window atomically via conditional UPDATE.
                // If another concurrent request consumed it first, 0 rows are affected.
                int consumed = refreshTokenRepository.consumeGraceWindowAtomically(storedToken.getId());
                storedToken.setRotatedAt(null);
                if (consumed == 0) {
                    logger.warn("SECURITY ALERT: Grace window was already consumed or concurrent replay detected for user: {}. Revoking entire token family.",
                            userEmail);
                    refreshTokenRepository.revokeAllByUser(user);
                    throw new BadCredentialsException("Refresh token reuse detected. All active sessions have been invalidated for security. Please log in again.");
                }

                logger.info("Grace window: Revoked refresh token presented within 15 seconds of rotation for user: {}. Re-issuing valid session and consuming grace window.",
                        userEmail);

                // Invalidate the old successor so it cannot be used
                if (storedToken.getSuccessorTokenHash() != null) {
                    refreshTokenRepository.findByTokenHash(storedToken.getSuccessorTokenHash()).ifPresent(succ -> {
                        succ.setRevoked(true);
                        refreshTokenRepository.save(succ);
                    });
                }

                String role = user != null && user.getRole() != null ? user.getRole() : "CUSTOMER";
                String newAccessToken = jwtService.generateToken(user.getEmail(), role, user.getUserId(), user.getName());
                String newRefreshToken = createRefreshTokenForUser(user);

                // Note: rotatedAt was set to null in DB and memory, so this token cannot be reused again
                storedToken.setSuccessorTokenHash(hashToken(newRefreshToken));
                refreshTokenRepository.save(storedToken);

                return new AuthResponse(
                        newAccessToken,
                        newRefreshToken,
                        jwtService.getExpirationInSeconds(),
                        user.getEmail(),
                        role,
                        user.getName(),
                        user.getUserId(),
                        user.getEmailVerified()
                );
            }

            // Outside grace window or grace window already consumed -> Token family reuse detection!
            logger.warn("SECURITY ALERT: Revoked refresh token reuse detected for user: {}. Revoking entire token family.",
                    userEmail);
            if (user != null) {
                refreshTokenRepository.revokeAllByUser(user);
            }
            throw new BadCredentialsException("Refresh token reuse detected. All active sessions have been invalidated for security. Please log in again.");
        }

        if (storedToken.getExpiryDate().isBefore(LocalDateTime.now(clock))) {
            storedToken.setRevoked(true);
            refreshTokenRepository.save(storedToken);
            throw new BadCredentialsException("Refresh token has expired");
        }

        // Single-use token rotation: revoke old token and issue a fresh pair
        storedToken.setRevoked(true);
        storedToken.setRotatedAt(LocalDateTime.now(clock));

        User user = storedToken.getUser();
        String role = user.getRole() != null ? user.getRole() : "CUSTOMER";
        String newAccessToken = jwtService.generateToken(user.getEmail(), role, user.getUserId(), user.getName());
        String newRefreshToken = createRefreshTokenForUser(user);
        storedToken.setSuccessorTokenHash(hashToken(newRefreshToken));
        refreshTokenRepository.save(storedToken);

        return new AuthResponse(
                newAccessToken,
                newRefreshToken,
                jwtService.getExpirationInSeconds(),
                user.getEmail(),
                role,
                user.getName(),
                user.getUserId(),
                user.getEmailVerified()
        );
    }

    @Transactional
    public Map<String, Object> logout(String rawRefreshToken, String userEmail) {
        if (rawRefreshToken != null && !rawRefreshToken.isBlank()) {
            String hashed = hashToken(rawRefreshToken.trim());
            refreshTokenRepository.findByTokenHash(hashed).ifPresent(token -> {
                token.setRevoked(true);
                refreshTokenRepository.save(token);
            });
        }
        if (userEmail != null && !userEmail.isBlank()) {
            userRepository.findByEmail(userEmail.toLowerCase().trim())
                    .ifPresent(refreshTokenRepository::revokeAllByUser);
        }
        return Map.of("message", "Logged out successfully");
    }

    @Transactional
    public Map<String, Object> verifyEmail(String token) {
        if (token == null || token.isBlank()) {
            throw new IllegalArgumentException("Verification token is required");
        }

        String hashedToken = hashToken(token.trim());
        User user = userRepository.findByEmailVerificationToken(hashedToken)
                .orElseThrow(() -> new IllegalArgumentException("Invalid verification token"));

        if (user.getEmailVerificationExpiry() != null && user.getEmailVerificationExpiry().isBefore(LocalDateTime.now())) {
            throw new IllegalArgumentException("Verification token has expired. Please request a new one.");
        }

        user.setEmailVerified(true);
        // Single-use: nullify token and expiry immediately
        user.setEmailVerificationToken(null);
        user.setEmailVerificationExpiry(null);
        userRepository.save(user);

        logger.info("Email verified successfully for: {}", user.getEmail());
        return Map.of("message", "Email verified successfully. You can now place orders.", "email", user.getEmail());
    }

    @Transactional
    public Map<String, Object> resendVerificationToken(String userEmail) {
        if (userEmail == null || userEmail.isBlank()) {
            throw new BadCredentialsException("User email is required");
        }
        User user = userRepository.findByEmail(userEmail.toLowerCase().trim())
                .orElseThrow(() -> new BadCredentialsException("User not found"));

        if (Boolean.TRUE.equals(user.getEmailVerified())) {
            return Map.of("message", "Email is already verified", "emailVerified", true);
        }

        String rawVerificationToken = UUID.randomUUID().toString();
        user.setEmailVerificationToken(hashToken(rawVerificationToken));
        user.setEmailVerificationExpiry(LocalDateTime.now().plusHours(24));
        userRepository.save(user);

        logger.info("New email verification token issued for user: {}", user.getEmail());
        logger.info("[DEV] Email verification link for {}: http://localhost:8080/api/auth/verify-email?token={}", user.getEmail(), rawVerificationToken);
        Map<String, Object> response = new HashMap<>();
        response.put("message", "Verification email resent successfully.");
        response.put("email", user.getEmail());
        response.put("verificationToken", rawVerificationToken);
        response.put("emailVerified", false);
        return response;
    }

    @Transactional
    public Map<String, Object> forgotPassword(ForgotPasswordRequest request) {
        String email = request.getEmail().toLowerCase().trim();
        Optional<User> userOpt = userRepository.findByEmail(email);

        Map<String, Object> response = new HashMap<>();
        response.put("message", "If an account exists with this email, password reset instructions have been generated.");

        if (userOpt.isPresent()) {
            User user = userOpt.get();
            String rawResetToken = UUID.randomUUID().toString();
            user.setPasswordResetToken(hashToken(rawResetToken));
            user.setPasswordResetExpiry(LocalDateTime.now().plusMinutes(15));
            userRepository.save(user);

            logger.info("Password reset token generated for {}", email);
            logger.info("[DEV] Password reset link for {}: http://localhost:8080/api/auth/reset-password?token={}", email, rawResetToken);
            // In dev/testing, return the raw token for client verification
            response.put("resetToken", rawResetToken);
        }

        return response;
    }

    @Transactional
    public Map<String, Object> resetPassword(ResetPasswordRequest request) {
        if (request.getToken() == null || request.getToken().isBlank()) {
            throw new IllegalArgumentException("Invalid or expired password reset token");
        }

        String hashedToken = hashToken(request.getToken().trim());
        User user = userRepository.findByPasswordResetToken(hashedToken)
                .orElseThrow(() -> new IllegalArgumentException("Invalid or expired password reset token"));

        if (user.getPasswordResetExpiry() != null && user.getPasswordResetExpiry().isBefore(LocalDateTime.now())) {
            throw new IllegalArgumentException("Password reset token has expired");
        }

        user.setPassword(passwordEncoder.encode(request.getNewPassword()));
        // Single-use: nullify token and expiry immediately
        user.setPasswordResetToken(null);
        user.setPasswordResetExpiry(null);
        userRepository.save(user);

        // Invalidate all active refresh tokens for this user so all sessions are revoked
        refreshTokenRepository.revokeAllByUser(user);

        logger.info("Password successfully reset and all sessions revoked for: {}", user.getEmail());
        return Map.of("message", "Password reset successfully. You can now log in with your new password.");
    }

    @Transactional
    public AuthResponse authenticateGoogleToken(GoogleAuthRequest request) {
        try {
            GoogleIdTokenVerifier verifier = new GoogleIdTokenVerifier.Builder(
                    new NetHttpTransport(),
                    GsonFactory.getDefaultInstance()
            )
                    .setAudience(googleClientId != null && !googleClientId.isBlank() ? Collections.singletonList(googleClientId) : null)
                    .build();

            GoogleIdToken idToken = verifier.verify(request.getIdToken());
            if (idToken == null) {
                throw new BadCredentialsException("Invalid Google ID token");
            }

            GoogleIdToken.Payload payload = idToken.getPayload();
            String email = payload.getEmail().toLowerCase();
            String name = (String) payload.get("name");

            User user = userRepository.findByEmail(email).orElseGet(() -> {
                User u = new User();
                u.setEmail(email);
                u.setName(name != null ? name : "Google User");
                u.setRole("CUSTOMER"); // Strictly default
                u.setEmailVerified(true);
                u.setCreatedAt(LocalDateTime.now());
                return userRepository.save(u);
            });

            // Google OAuth guarantees verified email
            if (!Boolean.TRUE.equals(user.getEmailVerified())) {
                user.setEmailVerified(true);
                userRepository.save(user);
            }

            String role = user.getRole() != null ? user.getRole() : "CUSTOMER";
            String accessToken = jwtService.generateToken(email, role, user.getUserId(), user.getName());
            String refreshToken = createRefreshTokenForUser(user);

            customerService.getOrCreateCustomer(email, role);

            return new AuthResponse(
                    accessToken,
                    refreshToken,
                    jwtService.getExpirationInSeconds(),
                    user.getEmail(),
                    role,
                    user.getName(),
                    user.getUserId(),
                    user.getEmailVerified()
            );

        } catch (BadCredentialsException e) {
            throw e;
        } catch (Exception e) {
            logger.error("Failed to verify Google ID token", e);
            throw new BadCredentialsException("Google authentication failed: " + e.getMessage());
        }
    }
}
