package com.example.zomato.controller;

import com.example.zomato.entity.Delivery;
import com.example.zomato.services.DeliveryService;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/delivery")
public class DeliveryController {

    private final DeliveryService deliveryService;

    public DeliveryController(DeliveryService deliveryService) {
        this.deliveryService = deliveryService;
    }

    @GetMapping("/{id}")
    public Delivery getById(@PathVariable int id) {
        return deliveryService.getDeliveryById(id)
                .orElseThrow(() -> new RuntimeException("Delivery not found"));
    }

    @PreAuthorize("hasRole('ADMIN')")
    @DeleteMapping("/{id}")
    public void delete(@PathVariable int id) {
        deliveryService.deleteDelivery(id);
    }

    @PreAuthorize("hasAnyRole('DELIVERY_PARTNER', 'ADMIN')")
    @PutMapping("/{id}/assign/{partnerId}")
    public Delivery assignPartner(@PathVariable int id, @PathVariable int partnerId) {
        return deliveryService.assignPartner(id, partnerId);
    }

    @GetMapping
    public List<Delivery> getAll() {
        return deliveryService.getAllDeliveries();
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @PostMapping
    public Delivery create(@RequestBody Delivery delivery) {
        return deliveryService.saveDelivery(delivery);
    }

    @PreAuthorize("hasAnyRole('DELIVERY_PARTNER', 'ADMIN')")
    @PutMapping("/{id}/status")
    public Delivery updateStatus(@PathVariable int id, @RequestBody Map<String, String> body) {
        return deliveryService.updateStatus(id, body.get("status"));
    }
}
