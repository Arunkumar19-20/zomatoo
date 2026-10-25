package com.example.zomato.config;

import com.example.zomato.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import static org.junit.jupiter.api.Assertions.assertTrue;

/** The demo-button accounts are for the demo and dev profiles only: a default (production-like) start must not create them. */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:no_demo_accounts;DB_CLOSE_DELAY=-1;MODE=PostgreSQL")
class DemoAccountsNotSeededByDefaultTest {

    @Autowired UserRepository users;

    @Test
    void noDemoButtonAccountsWithoutTheDemoProfile() {
        for (String email : new String[]{"aarav.sharma@gmail.com", "arunkumar2006.d@gmail.com", "rahul.singh@gmail.com", "admin1@zomato.com"}) {
            assertTrue(users.findByEmail(email).isEmpty(), email + " must not exist outside the demo and dev profiles");
        }
    }
}
