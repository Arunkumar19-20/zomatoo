package com.example.zomato.config;

import com.example.zomato.entity.Customer;
import com.example.zomato.entity.RestaurantOwner;
import com.example.zomato.repository.CustomerRepository;
import com.example.zomato.repository.RestaurantOwnerRepository;
import com.example.zomato.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import static org.junit.jupiter.api.Assertions.*;

/**
 * The app creates a bare customer record the moment something is added to the cart, which can happen before the demo account exists. Seeding the
 * account then must reuse that record: two rows for one email break every lookup ("Query did not return a unique result").
 */
@SpringBootTest(properties = {"spring.profiles.active=demo", "spring.datasource.url=jdbc:h2:mem:demo_existing;DB_CLOSE_DELAY=-1;MODE=PostgreSQL",
        "stripe.secret-key=sk_test_demo", "stripe.public-key=pk_test_demo", "stripe.webhook-secret=whsec_demo"})
class DemoAccountsExistingRecordsTest {

    @Autowired UserRepository users;
    @Autowired CustomerRepository customers;
    @Autowired RestaurantOwnerRepository owners;
    @Autowired DataInitializer seeder;

    private static final String CUSTOMER = "aarav.sharma@gmail.com";
    private static final String OWNER = "arunkumar2006.d@gmail.com";

    private long customerRows(String email) { return customers.findAll().stream().filter(c -> email.equalsIgnoreCase(c.getEmail())).count(); }

    @Test
    void anExistingBareCustomerAndOwnerAreReusedNotDuplicated() {
        // start from the state of a database where the demo button was used before the account existed
        customers.deleteAll(customers.findAll().stream().filter(c -> CUSTOMER.equalsIgnoreCase(c.getEmail())).toList());
        owners.deleteAll(owners.findByEmailIgnoreCase(OWNER));
        users.delete(users.findByEmail(CUSTOMER).orElseThrow());
        users.delete(users.findByEmail(OWNER).orElseThrow());
        Customer bare = new Customer();
        bare.setEmail(CUSTOMER);
        bare.setName("CUSTOMER");
        customers.save(bare);
        owners.save(new RestaurantOwner("Arun", OWNER, "0"));

        seeder.run();

        assertEquals(1, customerRows(CUSTOMER), "one customer for the email, never two");
        Customer c = customers.findByEmail(CUSTOMER).orElseThrow();
        assertEquals(users.findByEmail(CUSTOMER).orElseThrow().getUserId(), c.getUserId(), "the existing record is attached to the new account");
        assertEquals("Aarav Sharma", c.getName(), "and given a proper name");
        assertEquals(1, owners.findByEmailIgnoreCase(OWNER).size());
    }

    @Test
    void aFreshStartMakesExactlyOneOfEach() {
        seeder.run();
        seeder.run();
        assertEquals(1, customerRows(CUSTOMER));
        assertEquals(1, owners.findByEmailIgnoreCase(OWNER).size());
    }
}
