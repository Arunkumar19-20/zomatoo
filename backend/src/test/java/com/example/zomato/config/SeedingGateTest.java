package com.example.zomato.config;

import static org.junit.jupiter.api.Assertions.*;

/** What ships as the default, and what is never logged. The behaviour itself is in SeedingOffTest and SeedingOnTest. */
class SeedingGateTest {

    @org.junit.jupiter.api.Test
    void theDefaultInTheShippedConfigurationIsOff() throws Exception {
        String yml = java.nio.file.Files.readString(java.nio.file.Path.of("src/main/resources/application.yml"));
        assertTrue(yml.contains("demo-accounts: ${SEED_DEMO_ACCOUNTS:false}"), "the shipped default must be false");
    }

    @org.junit.jupiter.api.Test
    void passwordsAreNeverWrittenToTheLog() throws Exception {
        String src = java.nio.file.Files.readString(java.nio.file.Path.of("src/main/java/com/example/zomato/config/DataInitializer.java"));
        for (String line : src.split("\n")) {
            if (line.contains("logger.")) assertFalse(line.contains("Password123"), "logged credentials: " + line.trim());
        }
    }
}
