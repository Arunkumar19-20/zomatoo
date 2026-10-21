package com.example.zomato.controller;

import com.example.zomato.entity.Customer;
import com.example.zomato.security.JwtService;
import com.example.zomato.services.CustomerService;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/customer")
public class CustomerController {

    private final CustomerService customerService;

    public CustomerController(CustomerService customerService) {
        this.customerService = customerService;
    }

    @GetMapping("/profile")
    public Customer getProfile(Authentication authentication) {
        if (authentication == null || !(authentication.getPrincipal() instanceof String email)) {
            throw new RuntimeException("Not authenticated");
        }

        String role = (String) authentication.getCredentials();

        if (!"CUSTOMER".equalsIgnoreCase(role)) {
            throw new RuntimeException("Access denied! Only CUSTOMER allowed");
        }

        return customerService.getOrCreateCustomer(email, role);
    }
}
