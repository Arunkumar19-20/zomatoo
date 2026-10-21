package com.example.zomato.controller;

import com.example.zomato.dto.OrderResponseDTO;
import com.example.zomato.services.OrderService;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/orders")
public class OrderController {

    private final OrderService orderService;

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    @PostMapping("/checkout")
    public OrderResponseDTO checkout(Authentication authentication,
                                     @RequestParam(required = false) Integer restaurantId,
                                     @RequestParam(required = false) Integer reservationId) {
        String email = authentication.getName();
        if (reservationId != null) {
            return orderService.checkoutDropDto(email, reservationId);
        }
        return orderService.checkoutDto(email, restaurantId);
    }

    @GetMapping
    public List<OrderResponseDTO> getOrders(Authentication authentication) {
        return orderService.getCustomerOrders(authentication.getName());
    }

    @GetMapping("/my-orders")
    public List<OrderResponseDTO> getMyOrders(Authentication authentication) {
        return orderService.getCustomerOrders(authentication.getName());
    }

    @GetMapping("/{id}")
    public OrderResponseDTO getOrder(@PathVariable int id, Authentication authentication) {
        return orderService.getOrderDtoById(id, authentication.getName());
    }

    @PreAuthorize("hasAnyRole('OWNER', 'DELIVERY_PARTNER', 'ADMIN')")
    @PutMapping("/{id}/status")
    public OrderResponseDTO updateStatus(@PathVariable int id,
                                         @RequestParam String status,
                                         Authentication authentication) {
        return orderService.updateStatusDto(id, status, authentication.getName());
    }

    @DeleteMapping("/{id}")
    public String cancel(@PathVariable int id, Authentication authentication) {
        return orderService.cancelOrder(id, authentication.getName()) ? "Cancelled" : "Failed";
    }
}
