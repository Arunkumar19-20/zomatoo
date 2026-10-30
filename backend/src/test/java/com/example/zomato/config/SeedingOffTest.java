package com.example.zomato.config;

import com.example.zomato.repository.RestaurantRepository;
import com.example.zomato.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import static org.junit.jupiter.api.Assertions.*;

/** A fresh database that real people will use must not come with an admin whose password is in the repository. */
@SpringBootTest(properties = {"seed.demo-accounts=false", "spring.datasource.url=jdbc:h2:mem:seed_off;DB_CLOSE_DELAY=-1;MODE=PostgreSQL"})
class SeedingOffTest {
    @Autowired UserRepository users;
    @Autowired RestaurantRepository restaurants;

    @Test
    void noAccountWithAKnownPasswordAndNoSampleDataIsCreated() {
        for (String email : new String[]{"admin@cravey.com", "owner@cravey.com", "customer@cravey.com"}) {
            assertTrue(users.findByEmail(email).isEmpty(), email + " must not exist");
        }
        assertEquals(0, restaurants.count(), "no sample restaurant either");
    }
}
