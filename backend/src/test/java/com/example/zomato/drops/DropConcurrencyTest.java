package com.example.zomato.drops;

import com.example.zomato.entity.Drop;
import com.example.zomato.repository.DropRepository;
import com.example.zomato.services.DropService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.time.LocalDateTime;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.assertEquals;

@SpringBootTest
class DropConcurrencyTest {

    @Autowired DropService service;
    @Autowired DropRepository drops;
    @Autowired com.example.zomato.repository.RestaurantRepository restaurantRepo;

    @Test
    void neverOversells() throws Exception {
        com.example.zomato.entity.Restaurant restaurant = restaurantRepo.findAll().stream().findFirst().orElseGet(() -> {
            com.example.zomato.entity.Restaurant r = new com.example.zomato.entity.Restaurant();
            r.setName("Concurrency Test Kitchen");
            return restaurantRepo.save(r);
        });

        Drop d = new Drop();
        d.setTitle("Concurrency drop");
        d.setPrice(10);
        d.setTotalSlots(5);
        d.setRestaurantId(restaurant.getId());
        d.setStartsAt(LocalDateTime.now().minusMinutes(1));
        d.setEndsAt(LocalDateTime.now().plusHours(1));
        int id = drops.save(d).getId();

        int users = 50;
        ExecutorService pool = Executors.newFixedThreadPool(16);
        CountDownLatch go = new CountDownLatch(1);
        AtomicInteger ok = new AtomicInteger();
        for (int i = 0; i < users; i++) {
            String email = "user" + i + "@test.com";
            pool.submit(() -> {
                try { go.await(); service.reserve(id, email); ok.incrementAndGet(); }
                catch (Exception ignored) { }
            });
        }
        go.countDown();
        pool.shutdown();
        pool.awaitTermination(30, TimeUnit.SECONDS);

        assertEquals(5, ok.get());
        assertEquals(5, drops.findById(id).orElseThrow().getReservedSlots());
    }
}
