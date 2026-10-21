package com.example.zomato.drops;

import com.example.zomato.dto.OrderResponseDTO;
import com.example.zomato.dto.ReservationResponseDTO;
import com.example.zomato.entity.*;
import com.example.zomato.repository.DropRepository;
import com.example.zomato.repository.DropReservationRepository;
import com.example.zomato.repository.OrderRepository;
import com.example.zomato.repository.RestaurantRepository;
import com.example.zomato.repository.UserRepository;
import com.example.zomato.services.DropService;
import com.example.zomato.services.OrderService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
class DropLifecycleIntegrationTest {

    @Autowired private DropService dropService;
    @Autowired private DropRepository dropRepository;
    @Autowired private DropReservationRepository reservationRepository;
    @Autowired private OrderService orderService;
    @Autowired private OrderRepository orderRepository;
    @Autowired private UserRepository userRepository;
    @Autowired private RestaurantRepository restaurantRepository;

    private String testUserEmail = "customer@cravey.com";
    private int dropId;

    @BeforeEach
    void setUp() {
        Restaurant restaurant = restaurantRepository.findAll().stream().findFirst().orElseGet(() -> {
            Restaurant r = new Restaurant();
            r.setName("Test Drop Kitchen");
            r.setAddress("123 Food Street");
            return restaurantRepository.save(r);
        });

        Drop drop = new Drop();
        drop.setTitle("Truffle Caviar Burger Drop");
        drop.setDescription("Limited batch luxury burger");
        drop.setPrice(35.00);
        drop.setTotalSlots(2);
        drop.setReservedSlots(0);
        drop.setRestaurantId(restaurant.getId());
        drop.setStartsAt(LocalDateTime.now().minusMinutes(5));
        drop.setEndsAt(LocalDateTime.now().plusHours(2));
        dropId = dropRepository.save(drop).getId();
    }

    @Test
    void testFullSuccessfulDropLifecycle() {
        // 1. Reserve slot
        ReservationResponseDTO reservation = dropService.reserve(dropId, testUserEmail);
        assertNotNull(reservation);
        assertEquals("HELD", reservation.status());
        assertEquals(1, dropRepository.findById(dropId).orElseThrow().getReservedSlots());

        // 2. Checkout drop directly via reservationId
        OrderResponseDTO order = orderService.checkoutDropDto(testUserEmail, reservation.reservationId());
        assertNotNull(order);
        assertEquals("PLACED", order.getStatus());
        assertEquals(PaymentStatus.PENDING, order.getPaymentStatus());
        assertEquals(35.00, order.getTotalAmount(), 0.01);
        assertEquals(1, order.getItems().size());
        assertEquals("Truffle Caviar Burger Drop", order.getItems().get(0).getName());

        // Verify reservation holds orderId
        DropReservation heldRes = reservationRepository.findById(reservation.reservationId()).orElseThrow();
        assertEquals(order.getOrderId(), heldRes.getOrderId());
        assertEquals(ReservationStatus.HELD, heldRes.getStatus());

        // 3. Simulate successful payment confirmation
        boolean confirmed = dropService.confirmByOrderId(order.getOrderId());
        assertTrue(confirmed);

        DropReservation confirmedRes = reservationRepository.findById(reservation.reservationId()).orElseThrow();
        assertEquals(ReservationStatus.CONFIRMED, confirmedRes.getStatus());
        assertEquals(1, dropRepository.findById(dropId).orElseThrow().getReservedSlots());
    }

    @Test
    void testUserReleasesHoldFreesSlot() {
        ReservationResponseDTO reservation = dropService.reserve(dropId, testUserEmail);
        assertEquals(1, dropRepository.findById(dropId).orElseThrow().getReservedSlots());

        // Release hold
        dropService.release(reservation.reservationId(), testUserEmail);

        DropReservation releasedRes = reservationRepository.findById(reservation.reservationId()).orElseThrow();
        assertEquals(ReservationStatus.RELEASED, releasedRes.getStatus());
        assertEquals(0, dropRepository.findById(dropId).orElseThrow().getReservedSlots());
    }

    @Test
    void testSoldOutDropRejectsExcessReservations() {
        dropService.reserve(dropId, "user1@cravey.com");
        dropService.reserve(dropId, "user2@cravey.com");
        assertEquals(2, dropRepository.findById(dropId).orElseThrow().getReservedSlots());

        // 3rd user should be rejected (only 2 slots total)
        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () -> {
            dropService.reserve(dropId, "user3@cravey.com");
        });
        assertEquals(409, ex.getStatusCode().value());
    }
}
