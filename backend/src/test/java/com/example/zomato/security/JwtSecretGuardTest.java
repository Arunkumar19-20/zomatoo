package com.example.zomato.security;

import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.*;

/** The signing key published in the repository can sign a token for any account, so a production start must not accept it. */
class JwtSecretGuardTest {

    private static JwtService service(String secret, String... profiles) {
        JwtService s = new JwtService();
        ReflectionTestUtils.setField(s, "secret", secret);
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles(profiles);
        ReflectionTestUtils.setField(s, "environment", env);
        return s;
    }

    @Test
    void theProdProfileRefusesToStartOnTheKnownDefault() {
        for (String profile : new String[]{"prod", "production"}) {
            var e = assertThrows(IllegalStateException.class, () -> service(JwtService.KNOWN_DEFAULT_SECRET, profile).verifySecret());
            assertTrue(e.getMessage().contains("JWT_SECRET"));
        }
    }

    @Test
    void aRealSecretIsAcceptedEverywhere() {
        assertDoesNotThrow(() -> service("a-long-random-secret-nobody-has-seen-0123456789abcdef", "prod").verifySecret());
        assertDoesNotThrow(() -> service("a-long-random-secret-nobody-has-seen-0123456789abcdef").verifySecret());
    }

    @Test
    void localDevelopmentMayUseTheDefaultWithOnlyAWarning() {
        assertDoesNotThrow(() -> service(JwtService.KNOWN_DEFAULT_SECRET).verifySecret());
        assertDoesNotThrow(() -> service(JwtService.KNOWN_DEFAULT_SECRET, "dev").verifySecret());
        assertDoesNotThrow(() -> service(JwtService.KNOWN_DEFAULT_SECRET, "demo").verifySecret());
    }

    @Test
    void theConstantMatchesTheShippedConfiguration() throws Exception {
        String yml = java.nio.file.Files.readString(java.nio.file.Path.of("src/main/resources/application.yml"));
        assertTrue(yml.contains("${JWT_SECRET:" + JwtService.KNOWN_DEFAULT_SECRET + "}"), "the guard must check the same value the config falls back to");
    }
}
