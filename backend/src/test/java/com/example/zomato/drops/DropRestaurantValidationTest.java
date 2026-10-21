package com.example.zomato.drops;

import com.example.zomato.dto.CreateDropRequestDTO;
import com.example.zomato.entity.Drop;
import com.example.zomato.entity.Restaurant;
import com.example.zomato.repository.DropRepository;
import com.example.zomato.repository.RestaurantRepository;
import com.example.zomato.services.DropService;
import com.example.zomato.services.OrderService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("test")
public class DropRestaurantValidationTest {

    @Autowired
    private DropService dropService;

    @Autowired
    private DropRepository dropRepository;

    @Autowired
    private RestaurantRepository restaurantRepository;

    @Autowired
    private PlatformTransactionManager transactionManager;

    private TransactionTemplate transactionTemplate;
    private Restaurant validRestaurant;

    @BeforeEach
    void setUp() {
        transactionTemplate = new TransactionTemplate(transactionManager);
        validRestaurant = restaurantRepository.findAll().stream().findFirst().orElseGet(() -> {
            Restaurant r = new Restaurant();
            r.setName("Validation Kitchen");
            return restaurantRepository.save(r);
        });
    }

    @Test
    void testCreateDropFailsWhenRestaurantIdIsNull() {
        CreateDropRequestDTO request = new CreateDropRequestDTO(
                "No Restaurant Drop",
                "Description",
                null,
                25.0,
                null, // Null restaurant ID
                null,
                LocalDateTime.now(),
                LocalDateTime.now().plusHours(2),
                10
        );

        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () ->
                dropService.createDrop(request));
        assertEquals(400, ex.getStatusCode().value());
        assertTrue(ex.getReason().contains("Restaurant ID is required"));
    }

    @Test
    void testCreateDropFailsWhenRestaurantDoesNotExist() {
        CreateDropRequestDTO request = new CreateDropRequestDTO(
                "Non-existent Restaurant Drop",
                "Description",
                null,
                25.0,
                999999, // Does not exist
                null,
                LocalDateTime.now(),
                LocalDateTime.now().plusHours(2),
                10
        );

        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () ->
                dropService.createDrop(request));
        assertEquals(400, ex.getStatusCode().value());
        assertTrue(ex.getReason().contains("Restaurant not found"));
    }

    @Test
    void testCreateDropSucceedsWithValidRestaurant() {
        CreateDropRequestDTO request = new CreateDropRequestDTO(
                "Valid Restaurant Drop",
                "Description",
                null,
                25.0,
                validRestaurant.getId(),
                null,
                LocalDateTime.now(),
                LocalDateTime.now().plusHours(2),
                10
        );

        assertDoesNotThrow(() -> {
            var response = dropService.createDrop(request);
            assertEquals(validRestaurant.getId(), response.restaurantId());
        });
    }

    @Test
    void testDatabaseRejectsDropWithNullRestaurantId() {
        Drop drop = new Drop();
        drop.setTitle("Null Restaurant Entity Drop");
        drop.setPrice(30.0);
        drop.setTotalSlots(5);
        drop.setReservedSlots(0);
        drop.setStartsAt(LocalDateTime.now());
        drop.setEndsAt(LocalDateTime.now().plusHours(2));
        drop.setRestaurantId(null); // Explicit null violates nullable = false

        assertThrows(Exception.class, () -> {
            transactionTemplate.execute(status -> {
                dropRepository.saveAndFlush(drop);
                return null;
            });
        });
    }
}
