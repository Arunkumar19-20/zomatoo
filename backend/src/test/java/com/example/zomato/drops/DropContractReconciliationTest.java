package com.example.zomato.drops;

import com.example.zomato.dto.CreateDropRequestDTO;
import com.example.zomato.dto.DropResponseDTO;
import com.example.zomato.dto.ReservationResponseDTO;
import com.example.zomato.entity.*;
import com.example.zomato.repository.*;
import com.example.zomato.security.JwtService;
import com.example.zomato.services.DropService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.LocalDateTime;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class DropContractReconciliationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private DropService dropService;

    @Autowired
    private DropRepository dropRepository;

    @Autowired
    private DropReservationRepository reservationRepository;

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RestaurantRepository restaurantRepository;

    @Autowired
    private MenuItemRepository menuItemRepository;

    @Autowired
    private PlatformTransactionManager transactionManager;

    private TransactionTemplate transactionTemplate;
    private Restaurant restaurant;
    private Drop drop;
    private String aliceToken;
    private String bobToken;

    @BeforeEach
    void setUp() {
        transactionTemplate = new TransactionTemplate(transactionManager);

        transactionTemplate.execute(status -> {
            reservationRepository.deleteAll();
            dropRepository.deleteAll();
            orderRepository.deleteAll();

            userRepository.findByEmail("contract_alice@cravey.com").orElseGet(() -> {
                User u = new User("Alice", "contract_alice@cravey.com", "CUSTOMER");
                u.setPassword("Password123!");
                u.setEmailVerified(true);
                return userRepository.save(u);
            });

            userRepository.findByEmail("contract_bob@cravey.com").orElseGet(() -> {
                User u = new User("Bob", "contract_bob@cravey.com", "CUSTOMER");
                u.setPassword("Password123!");
                u.setEmailVerified(true);
                return userRepository.save(u);
            });

            restaurant = restaurantRepository.findAll().stream().findFirst().orElseGet(() -> {
                Restaurant r = new Restaurant();
                r.setName("Cravey Gourmet Bistro");
                r.setAddress("456 Culinary Ave");
                return restaurantRepository.save(r);
            });

            drop = new Drop();
            drop.setTitle("Truffle Wagyu Slider Drop");
            drop.setDescription("Limited edition wagyu sliders");
            drop.setImageUrl("https://example.com/wagyu.jpg");
            drop.setPrice(35.00);
            drop.setRestaurantId(restaurant.getId());
            drop.setTotalSlots(5);
            drop.setReservedSlots(0);
            drop.setStartsAt(LocalDateTime.now().minusMinutes(5));
            drop.setEndsAt(LocalDateTime.now().plusHours(2));
            drop = dropRepository.save(drop);

            return null;
        });

        aliceToken = "Bearer " + jwtService.generateToken("contract_alice@cravey.com", "CUSTOMER");
        bobToken = "Bearer " + jwtService.generateToken("contract_bob@cravey.com", "CUSTOMER");
    }

    @Test
    @DisplayName("Drop DTO includes restaurantId and restaurantName")
    void testDropDtoIncludesRestaurantIdAndName() throws Exception {
        mockMvc.perform(get("/drops/" + drop.getId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.restaurantId").value(restaurant.getId()))
                .andExpect(jsonPath("$.restaurantName").value(restaurant.getName()))
                .andExpect(jsonPath("$.serverTime").isNotEmpty());

        mockMvc.perform(get("/drops"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(greaterThanOrEqualTo(1))))
                .andExpect(jsonPath("$[0].restaurantName").isNotEmpty())
                .andExpect(jsonPath("$[0].serverTime").isNotEmpty());
    }

    @Test
    @DisplayName("Release endpoint: Only owner can release; non-owner gets 403 NOT_YOUR_RESERVATION")
    void testReleaseOwnerEnforcement() throws Exception {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "contract_alice@cravey.com");

        // Bob attempts to release Alice's reservation
        mockMvc.perform(delete("/drops/reservations/" + res.reservationId())
                        .header("Authorization", bobToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("NOT_YOUR_RESERVATION"))
                .andExpect(jsonPath("$.message").value("Not your reservation"));

        // Alice (owner) releases her own reservation -> 204 No Content
        mockMvc.perform(delete("/drops/reservations/" + res.reservationId())
                        .header("Authorization", aliceToken))
                .andExpect(status().isNoContent());

        // Verify slot was freed and status is CANCELLED
        DropReservation updated = reservationRepository.findById(res.reservationId()).orElseThrow();
        assertEquals(ReservationStatus.CANCELLED, updated.getStatus());
        Drop updatedDrop = dropRepository.findById(drop.getId()).orElseThrow();
        assertEquals(0, updatedDrop.getReservedSlots());
    }

    @Test
    @DisplayName("Release endpoint: Releasing non-HELD reservation returns 409 Conflict with exact code")
    void testReleaseNonHeldReservationReturns409() throws Exception {
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "contract_alice@cravey.com");

        // First release succeeds
        mockMvc.perform(delete("/drops/reservations/" + res.reservationId())
                        .header("Authorization", aliceToken))
                .andExpect(status().isNoContent());

        // Second release on now-CANCELLED reservation -> 409 Conflict
        mockMvc.perform(delete("/drops/reservations/" + res.reservationId())
                        .header("Authorization", aliceToken))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("HOLD_EXPIRED"));

        // Test releasing CONFIRMED reservation -> 409 RESERVATION_ALREADY_USED
        ReservationResponseDTO res2 = dropService.reserve(drop.getId(), "contract_alice@cravey.com");
        transactionTemplate.execute(status -> {
            DropReservation r = reservationRepository.findById(res2.reservationId()).orElseThrow();
            r.setStatus(ReservationStatus.CONFIRMED);
            reservationRepository.save(r);
            return null;
        });

        mockMvc.perform(delete("/drops/reservations/" + res2.reservationId())
                        .header("Authorization", aliceToken))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("RESERVATION_ALREADY_USED"))
                .andExpect(jsonPath("$.message").value("Reservation is already confirmed"));
    }

    @Test
    @DisplayName("GET /drops/reservations/mine returns active reservations with serverTime and excludes expired/cancelled")
    void testGetMyActiveReservations() throws Exception {
        // Unauthenticated access -> 401 Unauthorized
        mockMvc.perform(get("/drops/reservations/mine"))
                .andExpect(status().isUnauthorized());

        // Alice reserves a slot
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "contract_alice@cravey.com");

        mockMvc.perform(get("/drops/reservations/mine")
                        .header("Authorization", aliceToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)))
                .andExpect(jsonPath("$[0].reservationId").value(res.reservationId()))
                .andExpect(jsonPath("$[0].dropId").value(drop.getId()))
                .andExpect(jsonPath("$[0].status").value("HELD"))
                .andExpect(jsonPath("$[0].expiresAt").isNotEmpty())
                .andExpect(jsonPath("$[0].serverTime").isNotEmpty());

        // Bob calls /drops/reservations/mine -> empty list
        mockMvc.perform(get("/drops/reservations/mine")
                        .header("Authorization", bobToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(0)));

        // After Alice releases, /drops/reservations/mine no longer includes it
        mockMvc.perform(delete("/drops/reservations/" + res.reservationId())
                        .header("Authorization", aliceToken))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/drops/reservations/mine")
                        .header("Authorization", aliceToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(0)));
    }

    @Test
    @DisplayName("Standardized drop error bodies: DROP_NOT_FOUND, DROP_NOT_LIVE, SOLD_OUT, ALREADY_RESERVED")
    void testStandardizedDropErrorCodes() throws Exception {
        // 1. DROP_NOT_FOUND
        mockMvc.perform(get("/drops/999999"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("DROP_NOT_FOUND"))
                .andExpect(jsonPath("$.message").value("Drop not found"));

        // 2. DROP_NOT_LIVE (future drop)
        Drop futureDrop = transactionTemplate.execute(status -> {
            Drop d = new Drop();
            d.setTitle("Future Drop");
            d.setDescription("Future");
            d.setImageUrl("https://example.com/future.jpg");
            d.setPrice(20.0);
            d.setRestaurantId(restaurant.getId());
            d.setTotalSlots(5);
            d.setReservedSlots(0);
            d.setStartsAt(LocalDateTime.now().plusDays(1));
            d.setEndsAt(LocalDateTime.now().plusDays(2));
            return dropRepository.save(d);
        });

        mockMvc.perform(post("/drops/" + futureDrop.getId() + "/reserve")
                        .header("Authorization", aliceToken))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("DROP_NOT_LIVE"));

        // 3. SOLD_OUT
        Drop soldOutDrop = transactionTemplate.execute(status -> {
            Drop d = new Drop();
            d.setTitle("Sold Out Drop");
            d.setDescription("Sold Out");
            d.setImageUrl("https://example.com/soldout.jpg");
            d.setPrice(20.0);
            d.setRestaurantId(restaurant.getId());
            d.setTotalSlots(1);
            d.setReservedSlots(1);
            d.setStartsAt(LocalDateTime.now().minusMinutes(5));
            d.setEndsAt(LocalDateTime.now().plusHours(1));
            return dropRepository.save(d);
        });

        mockMvc.perform(post("/drops/" + soldOutDrop.getId() + "/reserve")
                        .header("Authorization", aliceToken))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("SOLD_OUT"))
                .andExpect(jsonPath("$.message").value("Drop is sold out"));

        // 4. ALREADY_RESERVED (when confirmed)
        ReservationResponseDTO res = dropService.reserve(drop.getId(), "contract_alice@cravey.com");
        transactionTemplate.execute(status -> {
            DropReservation r = reservationRepository.findById(res.reservationId()).orElseThrow();
            r.setStatus(ReservationStatus.CONFIRMED);
            reservationRepository.save(r);
            return null;
        });

        mockMvc.perform(post("/drops/" + drop.getId() + "/reserve")
                        .header("Authorization", aliceToken))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("ALREADY_RESERVED"));
    }

    @Test
    @DisplayName("Standardized drop checkout error bodies: RESERVATION_NOT_FOUND, NOT_YOUR_RESERVATION, HOLD_EXPIRED, RESERVATION_ALREADY_USED")
    void testStandardizedCheckoutErrorCodes() throws Exception {
        // 1. RESERVATION_NOT_FOUND
        mockMvc.perform(post("/orders/checkout")
                        .header("Authorization", aliceToken)
                        .param("reservationId", "999999"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("RESERVATION_NOT_FOUND"))
                .andExpect(jsonPath("$.message").value("Reservation not found"));

        ReservationResponseDTO res = dropService.reserve(drop.getId(), "contract_alice@cravey.com");

        // 2. NOT_YOUR_RESERVATION
        mockMvc.perform(post("/orders/checkout")
                        .header("Authorization", bobToken)
                        .param("reservationId", String.valueOf(res.reservationId())))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("NOT_YOUR_RESERVATION"))
                .andExpect(jsonPath("$.message").value("Not your reservation"));

        // 3. HOLD_EXPIRED
        transactionTemplate.execute(status -> {
            DropReservation r = reservationRepository.findById(res.reservationId()).orElseThrow();
            r.setExpiresAt(LocalDateTime.now().minusMinutes(5));
            reservationRepository.save(r);
            return null;
        });

        mockMvc.perform(post("/orders/checkout")
                        .header("Authorization", aliceToken)
                        .param("reservationId", String.valueOf(res.reservationId())))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("HOLD_EXPIRED"));

        // 4. RESERVATION_ALREADY_USED
        ReservationResponseDTO res2 = dropService.reserve(drop.getId(), "contract_bob@cravey.com");
        mockMvc.perform(post("/orders/checkout")
                        .header("Authorization", bobToken)
                        .param("reservationId", String.valueOf(res2.reservationId())))
                .andExpect(status().isOk());

        mockMvc.perform(post("/orders/checkout")
                        .header("Authorization", bobToken)
                        .param("reservationId", String.valueOf(res2.reservationId())))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("RESERVATION_ALREADY_USED"));
    }
}
