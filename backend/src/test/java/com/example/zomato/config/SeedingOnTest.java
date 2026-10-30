package com.example.zomato.config;

import com.example.zomato.repository.RestaurantRepository;
import com.example.zomato.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest(properties = {"seed.demo-accounts=true", "spring.datasource.url=jdbc:h2:mem:seed_on;DB_CLOSE_DELAY=-1;MODE=PostgreSQL"})
class SeedingOnTest {
    @Autowired UserRepository users;
    @Autowired RestaurantRepository restaurants;

    @Test
    void theFlagTurnsItOnForLocalDevelopment() {
        assertTrue(users.findByEmail("admin@cravey.com").isPresent());
        assertTrue(users.findByEmail("owner@cravey.com").isPresent());
        assertTrue(restaurants.count() > 0);
    }
}
