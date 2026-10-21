package com.example.zomato.drops;

import com.example.zomato.dto.ReservationResponseDTO;
import com.example.zomato.entity.*;
import com.example.zomato.repository.DropRepository;
import com.example.zomato.repository.DropReservationRepository;
import com.example.zomato.repository.RestaurantRepository;
import com.example.zomato.security.JwtService;
import com.example.zomato.security.RateLimitingService;
import com.example.zomato.services.DropService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class DropAntiHoardingAndIdempotencyTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private DropService dropService;

    @Autowired
    private DropRepository dropRepository;

    @Autowired
    private DropReservationRepository reservationRepository;

    @Autowired
    private RestaurantRepository restaurantRepository;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private RateLimitingService rateLimitingService;

    private Restaurant restaurant;
    private Drop drop;

    @BeforeEach
    void setUp() {
        rateLimitingService.reset();
        reservationRepository.deleteAll();
        dropRepository.deleteAll();

        restaurant = restaurantRepository.findAll().stream().findFirst().orElseGet(() -> {
            Restaurant r = new Restaurant();
            r.setName("Anti-Hoarding Kitchen");
            return restaurantRepository.save(r);
        });

        Drop d = new Drop();
        d.setTitle("Limited Artisanal Ramen");
        d.setPrice(35.0);
        d.setTotalSlots(10);
        d.setReservedSlots(0);
        d.setRestaurantId(restaurant.getId());
        d.setStartsAt(LocalDateTime.now().minusMinutes(5));
        d.setEndsAt(LocalDateTime.now().plusHours(2));
        drop = dropRepository.save(d);
    }

    @Test
    void testReserveIdempotencyReturnsExistingHeldReservationWithHttp200() throws Exception {
        String email = "hoarder_sam@test.com";
        String token = "Bearer " + jwtService.generateToken(email, "CUSTOMER");

        // 1. Initial reservation returns 201 Created
        var initialRes = mockMvc.perform(post("/drops/" + drop.getId() + "/reserve")
                        .header("Authorization", token))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.reservationId").isNumber())
                .andReturn();

        int reservationId = dropRepository.findById(drop.getId()).orElseThrow().getReservedSlots();
        assertEquals(1, reservationId, "Drop reserved slots should be 1");

        // 2. Retry with same user returns 200 OK with the exact same reservationId
        mockMvc.perform(post("/drops/" + drop.getId() + "/reserve")
                        .header("Authorization", token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("HELD"));

        // Slots must NOT be incremented again (no double-counting)
        Drop refreshedDrop = dropRepository.findById(drop.getId()).orElseThrow();
        assertEquals(1, refreshedDrop.getReservedSlots(), "Available slots must not decrease on retry");
        assertEquals(9, refreshedDrop.getAvailableSlots());
    }

    @Test
    void testConfirmedReservationBlocksSubsequentReservesWithConflict409() throws Exception {
        String email = "confirmed_sam@test.com";
        String token = "Bearer " + jwtService.generateToken(email, "CUSTOMER");

        // Create reservation and transition to CONFIRMED
        ReservationResponseDTO res = dropService.reserve(drop.getId(), email);
        DropReservation entity = reservationRepository.findById(res.reservationId()).orElseThrow();
        entity.setStatus(ReservationStatus.CONFIRMED);
        reservationRepository.save(entity);

        // Next reserve attempt must return 409 Conflict ALREADY_RESERVED
        mockMvc.perform(post("/drops/" + drop.getId() + "/reserve")
                        .header("Authorization", token))
                .andExpect(status().isConflict());
    }

    @Test
    void testConcurrentReservesFromSameUserReturnSameReservationAndNoSlotLeak() throws Exception {
        String email = "concurrent_shopper@test.com";
        int threads = 10;
        ExecutorService executor = Executors.newFixedThreadPool(threads);
        CountDownLatch ready = new CountDownLatch(threads);
        CountDownLatch start = new CountDownLatch(1);

        List<ReservationResponseDTO> results = Collections.synchronizedList(new ArrayList<>());
        AtomicInteger failures = new AtomicInteger();

        for (int i = 0; i < threads; i++) {
            executor.submit(() -> {
                ready.countDown();
                try {
                    start.await();
                    ReservationResponseDTO res = dropService.reserve(drop.getId(), email);
                    results.add(res);
                } catch (Exception e) {
                    failures.incrementAndGet();
                }
            });
        }

        ready.await();
        start.countDown();
        executor.shutdown();
        assertTrue(executor.awaitTermination(15, TimeUnit.SECONDS));

        assertFalse(results.isEmpty(), "At least one reservation must succeed");

        // Verify that all successful results refer to the exact same reservation ID
        int firstResId = results.get(0).reservationId();
        for (ReservationResponseDTO r : results) {
            assertEquals(firstResId, r.reservationId(), "All concurrent calls must resolve to the identical reservation ID");
        }

        // Verify slot accounting invariant: exactly 1 slot occupied by this user
        Drop refreshedDrop = dropRepository.findById(drop.getId()).orElseThrow();
        assertEquals(1, refreshedDrop.getReservedSlots(), "Only 1 slot should be occupied despite concurrent attempts");
        long activeCount = reservationRepository.countByDrop_IdAndStatusIn(drop.getId(), List.of(ReservationStatus.HELD, ReservationStatus.CONFIRMED));
        assertEquals(1, activeCount);
        assertEquals(refreshedDrop.getReservedSlots(), activeCount, "Invariant must strictly hold");
    }

    @Test
    void testRateLimitingEnforcedOnReserveEndpoint() throws Exception {
        String email = "rate_limited_user@test.com";
        String token = "Bearer " + jwtService.generateToken(email, "CUSTOMER");

        // 10 requests allowed
        for (int i = 0; i < 10; i++) {
            mockMvc.perform(post("/drops/" + drop.getId() + "/reserve")
                            .header("Authorization", token))
                    .andExpect(status().is2xxSuccessful());
        }

        // 11th request in the same minute is rate-limited (429 Too Many Requests)
        mockMvc.perform(post("/drops/" + drop.getId() + "/reserve")
                        .header("Authorization", token))
                .andExpect(status().isTooManyRequests());
    }
}
