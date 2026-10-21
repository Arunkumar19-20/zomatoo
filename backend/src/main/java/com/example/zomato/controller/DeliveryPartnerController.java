package com.example.zomato.controller;

import com.example.zomato.entity.DeliveryPartner;
import com.example.zomato.entity.Location;
import com.example.zomato.services.DeliveryPartnerService;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/delivery-partners")
public class DeliveryPartnerController {

    private final DeliveryPartnerService service;

    public DeliveryPartnerController(DeliveryPartnerService service) {
        this.service = service;
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping
    public DeliveryPartner create(@RequestBody DeliveryPartner partner) {
        return service.savePartner(partner);
    }

    @PreAuthorize("hasAnyRole('DELIVERY_PARTNER', 'ADMIN')")
    @GetMapping("/{id}")
    public DeliveryPartner getById(@PathVariable Integer id) {
        return service.getPartnerById(id);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @GetMapping
    public List<DeliveryPartner> getAll() {
        return service.getAllPartners();
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PutMapping("/{id}")
    public DeliveryPartner update(@PathVariable Integer id, @RequestBody DeliveryPartner partner) {
        return service.updatePartner(id, partner);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @DeleteMapping("/{id}")
    public void delete(@PathVariable Integer id) {
        service.deletePartner(id);
    }

    @PreAuthorize("hasAnyRole('DELIVERY_PARTNER', 'ADMIN')")
    @PostMapping("/{id}/accept-order/{orderId}")
    public boolean acceptOrder(@PathVariable Integer id, @PathVariable Integer orderId) {
        return service.acceptOrder(id, orderId);
    }

    @PreAuthorize("hasAnyRole('DELIVERY_PARTNER', 'ADMIN')")
    @PutMapping("/{id}/location")
    public void updateLocation(@PathVariable Integer id, @RequestBody Location location) {
        service.updateLocation(id, location);
    }

    @PreAuthorize("hasAnyRole('DELIVERY_PARTNER', 'ADMIN')")
    @PostMapping("/{id}/complete-order/{orderId}")
    public void completeDelivery(@PathVariable Integer id, @PathVariable Integer orderId) {
        service.completeDelivery(id, orderId);
    }

    @PreAuthorize("hasAnyRole('DELIVERY_PARTNER', 'ADMIN')")
    @PutMapping("/{id}/availability")
    public void updateAvailability(@PathVariable Integer id, @RequestParam boolean isAvailable) {
        service.updateAvailability(id, isAvailable);
    }
}
