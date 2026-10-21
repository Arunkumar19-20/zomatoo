package com.example.zomato.auth;

import com.example.zomato.entity.User;
import com.example.zomato.repository.RefreshTokenRepository;
import com.example.zomato.repository.UserRepository;
import com.example.zomato.security.JwtService;
import com.example.zomato.security.RateLimitingService;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
public class AuthenticationIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private RateLimitingService rateLimitingService;

    @BeforeEach
    void setUp() {
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();
        rateLimitingService.reset();
    }

    @Test
    void testRegistrationAndVerificationFlow() throws Exception {
        // 1. Register new user
        String registerJson = """
            {
                "name": "Alice Green",
                "email": "alice@example.com",
                "password": "Password123!"
            }
            """;

        var registerResult = mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(registerJson))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.emailVerified").value(false))
                .andExpect(jsonPath("$.role").value("CUSTOMER"))
                .andExpect(jsonPath("$.verificationToken").isNotEmpty())
                .andReturn();

        String rawVerificationToken = JsonPath.read(registerResult.getResponse().getContentAsString(), "$.verificationToken");

        User savedUser = userRepository.findByEmail("alice@example.com").orElseThrow();
        assertFalse(savedUser.getEmailVerified());
        assertNotNull(savedUser.getEmailVerificationToken());
        // Verify database stores HASH, not raw token
        assertNotEquals(rawVerificationToken, savedUser.getEmailVerificationToken());
        assertTrue(passwordEncoder.matches("Password123!", savedUser.getPassword()));

        // 2. Unverified user cannot checkout
        String token = "Bearer " + jwtService.generateToken("alice@example.com", "CUSTOMER");
        mockMvc.perform(post("/orders/checkout")
                        .header("Authorization", token))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.message").value("Please verify your email before placing an order."));

        // 3. Verify email with raw token
        mockMvc.perform(get("/api/auth/verify-email")
                        .param("token", rawVerificationToken))
                .andExpect(status().isOk());

        User verifiedUser = userRepository.findByEmail("alice@example.com").orElseThrow();
        assertTrue(verifiedUser.getEmailVerified());
        // Single-use: verification token wiped from DB
        assertNull(verifiedUser.getEmailVerificationToken());
        assertNull(verifiedUser.getEmailVerificationExpiry());

        // 4. Login after verification
        String loginJson = """
            {
                "email": "alice@example.com",
                "password": "Password123!"
            }
            """;

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginJson))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                .andExpect(jsonPath("$.expiresIn").value(900))
                .andExpect(jsonPath("$.emailVerified").value(true));
    }

    @Test
    void testLoginWithWrongPasswordFails() throws Exception {
        User user = new User("Bob", "bob@example.com", "CUSTOMER");
        user.setPassword(passwordEncoder.encode("Secret123!"));
        user.setEmailVerified(true);
        userRepository.save(user);

        String badLoginJson = """
            {
                "email": "bob@example.com",
                "password": "WrongPassword!"
            }
            """;

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(badLoginJson))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void testPasswordResetFlow() throws Exception {
        User user = new User("Charlie", "charlie@example.com", "CUSTOMER");
        user.setPassword(passwordEncoder.encode("OldPassword123!"));
        user.setEmailVerified(true);
        userRepository.save(user);

        // Forgot password request
        String forgotJson = """
            {
                "email": "charlie@example.com"
            }
            """;

        var forgotResult = mockMvc.perform(post("/api/auth/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(forgotJson))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.resetToken").isNotEmpty())
                .andReturn();

        String rawResetToken = JsonPath.read(forgotResult.getResponse().getContentAsString(), "$.resetToken");

        User userWithToken = userRepository.findByEmail("charlie@example.com").orElseThrow();
        assertNotNull(userWithToken.getPasswordResetToken());
        // Verify database stores HASH, not raw token
        assertNotEquals(rawResetToken, userWithToken.getPasswordResetToken());

        // Reset password request with raw token
        String resetJson = String.format("""
            {
                "token": "%s",
                "newPassword": "NewSuperPassword456!"
            }
            """, rawResetToken);

        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(resetJson))
                .andExpect(status().isOk());

        User updatedUser = userRepository.findByEmail("charlie@example.com").orElseThrow();
        assertTrue(passwordEncoder.matches("NewSuperPassword456!", updatedUser.getPassword()));
        // Single-use: reset token wiped from DB
        assertNull(updatedUser.getPasswordResetToken());
        assertNull(updatedUser.getPasswordResetExpiry());
    }
}
