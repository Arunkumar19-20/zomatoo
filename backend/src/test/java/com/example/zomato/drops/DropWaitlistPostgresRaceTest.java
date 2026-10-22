package com.example.zomato.drops;

import com.example.zomato.entity.*;
import com.example.zomato.exception.DropApiException;
import com.example.zomato.repository.*;
import com.example.zomato.services.DropService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Real-Postgres proof that slot accounting, the one-active-reservation index and the FIFO waitlist hand-off hold
 * under concurrency, including two app instances racing for the same customer.
 */
@Tag("postgres")
@Testcontainers
@SpringBootTest
@ActiveProfiles("test")
public class DropWaitlistPostgresRaceTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("zomato_waitlist_test")
            .withUsername("postgres")
            .withPassword("postgres");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.driverClassName", () -> "org.postgresql.Driver");
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
        registry.add("spring.jpa.database-platform", () -> "org.hibernate.dialect.PostgreSQLDialect");
        registry.add("spring.jpa.hibernate.ddl-auto", () -> "update");
        registry.add("spring.flyway.enabled", () -> "true");
        registry.add("spring.flyway.baseline-on-migrate", () -> "true");
        registry.add("drops.max-per-user", () -> "1");
    }

    @Autowired private DropService dropService;
    @Autowired private DropRepository dropRepository;
    @Autowired private DropReservationRepository reservationRepository;
    @Autowired private DropWaitlistRepository waitlistRepository;
    @Autowired private RestaurantRepository restaurantRepository;
    @Autowired private OrderRepository orderRepository;
    @Autowired private PaymentRepository paymentRepository;
    @Autowired private PlatformTransactionManager transactionManager;
    @Autowired private JdbcTemplate jdbc;

    private TransactionTemplate tx;
    private Restaurant restaurant;

    @BeforeEach
    void setUp() {
        tx = new TransactionTemplate(transactionManager);
        tx.execute(status -> {
            paymentRepository.deleteAll();
            waitlistRepository.deleteAll();
            reservationRepository.deleteAll();
            orderRepository.deleteAll();
            restaurant = restaurantRepository.findAll().stream().findFirst().orElseGet(() -> {
                Restaurant r = new Restaurant();
                r.setName("Waitlist Race Kitchen");
                return restaurantRepository.save(r);
            });
            return null;
        });
    }

    private Drop newDrop(int slots) {
        return tx.execute(status -> {
            Drop d = new Drop();
            d.setTitle("Race Drop " + slots);
            d.setPrice(20.0);
            d.setTotalSlots(slots);
            d.setReservedSlots(0);
            d.setRestaurantId(restaurant.getId());
            d.setStartsAt(LocalDateTime.now().minusMinutes(5));
            d.setEndsAt(LocalDateTime.now().plusHours(1));
            return dropRepository.save(d);
        });
    }

    private void assertInvariant(int dropId) {
        Drop d = dropRepository.findById(dropId).orElseThrow();
        long active = reservationRepository.countByDrop_IdAndStatusIn(dropId, List.of(ReservationStatus.HELD, ReservationStatus.CONFIRMED));
        assertEquals(d.getReservedSlots(), active, "reservedSlots == HELD + CONFIRMED");
        assertTrue(d.getReservedSlots() >= 0 && d.getReservedSlots() <= d.getTotalSlots(), "0 <= reserved <= total");
        Integer dupes = jdbc.queryForObject(
                "select count(*) from (select customer_email from drop_reservations where drop_id = ? and status in ('HELD','CONFIRMED') " +
                        "group by customer_email having count(*) > 1) x", Integer.class, dropId);
        assertEquals(0, dupes, "no customer holds two slots");
    }

    private <T> List<T> runConcurrently(int n, java.util.function.IntFunction<Callable<T>> job) throws Exception {
        ExecutorService pool = Executors.newFixedThreadPool(n);
        CountDownLatch go = new CountDownLatch(1);
        List<Future<T>> futures = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            Callable<T> c = job.apply(i);
            futures.add(pool.submit(() -> { go.await(); return c.call(); }));
        }
        go.countDown();
        List<T> out = new ArrayList<>();
        for (Future<T> f : futures) out.add(f.get(60, TimeUnit.SECONDS));
        pool.shutdown();
        return out;
    }

    @Test
    void sameCustomerRacingThroughTwoAppInstancesNeverDoubleHolds() throws Exception {
        Drop drop = newDrop(5);
        // A second DropService has its own JVM lock map, so only the database can arbitrate - like two app servers.
        DropService otherInstance = new DropService(dropRepository, reservationRepository, waitlistRepository, restaurantRepository, transactionManager);

        AtomicInteger created = new AtomicInteger();
        AtomicInteger returnedExisting = new AtomicInteger();
        AtomicInteger conflicts = new AtomicInteger();
        runConcurrently(24, i -> () -> {
            DropService svc = i % 2 == 0 ? dropService : otherInstance;
            try {
                DropService.ReserveResult r = svc.reserveWithResult(drop.getId(), "twin@cravey.com");
                if (r.created()) created.incrementAndGet(); else returnedExisting.incrementAndGet();
            } catch (DropApiException e) {
                assertEquals("ALREADY_RESERVED", e.getCode());
                conflicts.incrementAndGet();
            }
            return null;
        });

        assertEquals(1, created.get(), "exactly one request creates the hold");
        assertEquals(24, created.get() + returnedExisting.get() + conflicts.get());
        assertEquals(1, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots(),
                "losing transactions must roll back their slot increment");
        assertInvariant(drop.getId());
    }

    @Test
    void fiveHundredCustomersFightForTwentySlotsWithZeroOversell() throws Exception {
        int slots = 20;
        int customers = 500;
        Drop drop = newDrop(slots);

        long started = System.nanoTime();
        List<String> outcomes = runConcurrently(customers, i -> () -> {
            try {
                dropService.reserve(drop.getId(), "load" + i + "@cravey.com");
                return "HELD";
            } catch (DropApiException e) {
                return e.getCode();
            }
        });
        long millis = (System.nanoTime() - started) / 1_000_000;

        Map<String, Long> tally = outcomes.stream().collect(Collectors.groupingBy(o -> o, TreeMap::new, Collectors.counting()));
        System.out.printf("LOAD-REPORT customers=%d slots=%d wallMillis=%d outcomes=%s%n", customers, slots, millis, tally);

        assertEquals(slots, tally.getOrDefault("HELD", 0L), "exactly `slots` customers win");
        assertEquals(customers - slots, tally.getOrDefault("SOLD_OUT", 0L), "everybody else is told it is sold out");
        assertEquals(customers, tally.values().stream().mapToLong(Long::longValue).sum(), "no request failed in any other way");
        assertEquals(slots, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());
        assertInvariant(drop.getId());
    }

    @Test
    void partialUniqueIndexesExistAndSameCustomerCannotQueueTwiceAcrossInstances() throws Exception {
        List<String> indexes = jdbc.queryForList("select indexname from pg_indexes where indexname like 'idx_drop_%'", String.class);
        assertTrue(indexes.contains("idx_drop_res_active_unique"), indexes.toString());
        assertTrue(indexes.contains("idx_drop_waitlist_active_unique"), indexes.toString());

        Drop drop = newDrop(1);
        dropService.reserve(drop.getId(), "holder@cravey.com");
        DropService otherInstance = new DropService(dropRepository, reservationRepository, waitlistRepository, restaurantRepository, transactionManager);

        List<Integer> entryIds = runConcurrently(24, i -> () -> (i % 2 == 0 ? dropService : otherInstance)
                .joinWaitlist(drop.getId(), "queuer@cravey.com").entryId());

        assertEquals(1, new HashSet<>(entryIds).size(), "every request resolves to the same single entry");
        assertEquals(1, waitlistRepository.countByDrop_IdAndStatus(drop.getId(), WaitlistStatus.WAITING));
    }

    @Test
    void settledDropCanBeDeletedDespiteForeignKeys() {
        Drop drop = newDrop(1);
        DropReservation r = reservationRepository.findById(dropService.reserve(drop.getId(), "gone@cravey.com").reservationId()).orElseThrow();
        dropService.release(r.getId(), "gone@cravey.com");

        dropService.deleteDrop(drop.getId());

        assertTrue(dropRepository.findById(drop.getId()).isEmpty());
    }

    @Test
    void concurrentHandOffsServeTheOldestWaitersInOrder() throws Exception {
        int slots = 5;
        Drop drop = newDrop(slots);

        // 5 winners, then 25 people queue up one after another so their order is well defined
        for (int i = 0; i < slots; i++) dropService.reserve(drop.getId(), "winner" + i + "@cravey.com");
        List<String> queue = new ArrayList<>();
        for (int i = 0; i < 25; i++) {
            String email = "waiter" + String.format("%02d", i) + "@cravey.com";
            dropService.joinWaitlist(drop.getId(), email);
            queue.add(email);
        }
        assertEquals(slots, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());

        // All winners give their slot back at the same instant
        List<Integer> winnerHolds = reservationRepository.findAll().stream()
                .filter(r -> r.getCustomerEmail().startsWith("winner")).map(DropReservation::getId).toList();
        runConcurrently(winnerHolds.size(), i -> () -> {
            dropService.release(winnerHolds.get(i), "winner" + i + "@cravey.com");
            return null;
        });

        Set<String> holders = reservationRepository.findAll().stream()
                .filter(r -> r.getStatus() == ReservationStatus.HELD).map(DropReservation::getCustomerEmail).collect(Collectors.toSet());
        assertEquals(new HashSet<>(queue.subList(0, slots)), holders, "the 5 oldest waiters hold the 5 freed slots");
        assertEquals(slots, dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots());
        assertInvariant(drop.getId());

        // and nobody can jump the queue in the meantime
        DropApiException sold = assertThrows(DropApiException.class, () -> dropService.reserve(drop.getId(), "sniper@cravey.com"));
        assertEquals("SOLD_OUT", sold.getCode());
    }

    @Test
    void chaosOfReserveJoinReleaseAndExpiryKeepsAccountingExact() throws Exception {
        int slots = 6;
        Drop drop = newDrop(slots);
        int users = 60;
        Random rnd = new Random(42);
        dropService.setWaitlistMaxPerSlot(20); // 54 people queue up in this scenario

        // Phase 1: everyone races to reserve; those turned away join the waitlist - all concurrently
        List<String> outcomes = runConcurrently(users, i -> () -> {
            String email = "chaos" + i + "@cravey.com";
            try {
                dropService.reserve(drop.getId(), email);
                return "HELD";
            } catch (DropApiException e) {
                if (!"SOLD_OUT".equals(e.getCode())) throw e;
                try {
                    dropService.joinWaitlist(drop.getId(), email);
                    return "WAITING";
                } catch (DropApiException e2) {
                    // a slot freed up between the two calls: perfectly legal, take it directly
                    if ("SLOTS_AVAILABLE".equals(e2.getCode())) {
                        dropService.reserve(drop.getId(), email);
                        return "HELD";
                    }
                    throw e2;
                }
            }
        });
        assertEquals(slots, outcomes.stream().filter("HELD"::equals).count() , "exactly `slots` customers got a hold");
        assertInvariant(drop.getId());

        // Phase 2: rounds of random releases, expiries and sweeps, each round concurrent
        for (int round = 0; round < 12; round++) {
            List<DropReservation> held = reservationRepository.findAll().stream()
                    .filter(r -> r.getStatus() == ReservationStatus.HELD).collect(Collectors.toList());
            Collections.shuffle(held, rnd);
            List<DropReservation> toRelease = held.subList(0, Math.min(2, held.size()));
            List<DropReservation> toExpire = held.subList(Math.min(2, held.size()), Math.min(4, held.size()));

            for (DropReservation r : toExpire) {
                tx.execute(s -> { DropReservation x = reservationRepository.findById(r.getId()).orElseThrow(); x.setExpiresAt(LocalDateTime.now().minusSeconds(1)); reservationRepository.save(x); return null; });
            }
            List<Callable<Object>> jobs = new ArrayList<>();
            for (DropReservation r : toRelease) jobs.add(() -> { try { dropService.release(r.getId(), r.getCustomerEmail()); } catch (DropApiException ignored) { } return null; });
            jobs.add(() -> dropService.expireStaleHolds());
            jobs.add(() -> dropService.promoteWaitlists());
            runConcurrently(jobs.size(), i -> () -> jobs.get(i).call());
            dropService.expireStaleHolds(); // settle anything a concurrent sweep missed
            dropService.promoteWaitlists(); // the scheduler's safety net for rare interleavings

            assertInvariant(drop.getId());
            long waiting = waitlistRepository.countByDrop_IdAndStatus(drop.getId(), WaitlistStatus.WAITING);
            int reserved = dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots();
            if (waiting > 0) {
                assertEquals(slots, reserved, "while people wait, no slot may sit idle (round " + round + ")");
            }
        }
    }

    @AfterEach
    void restoreDefaults() {
        dropService.setWaitlistMaxPerSlot(5);
    }
}
