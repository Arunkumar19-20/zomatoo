package com.example.zomato.services;

import com.example.zomato.entity.Cart;
import com.example.zomato.entity.Customer;
import com.example.zomato.repository.CartRepository;
import com.example.zomato.repository.CustomerRepository;
import org.springframework.stereotype.Service;

@Service
public class CustomerService {

    private final CustomerRepository customerRepo;
    private final CartRepository cartRepo;

    public CustomerService(CustomerRepository customerRepo, CartRepository cartRepo) {
        this.customerRepo = customerRepo;
        this.cartRepo = cartRepo;
    }

    public Customer getOrCreateCustomer(String email, String roleOrName) {

        Customer customer = customerRepo.findByEmail(email)
                .orElseGet(() -> {
                    Customer c = new Customer();
                    c.setEmail(email);
                    c.setName(roleOrName != null && !roleOrName.isBlank() ? roleOrName : "Customer");
                    return customerRepo.save(c);
                });

        boolean cartExists = cartRepo.findByCustomer_CustomerId(customer.getCustomerId()).isPresent();

        if (!cartExists) {
            Cart cart = new Cart();
            cart.setCustomer(customer);
            cart.setTotalAmount(0.0);
            cartRepo.save(cart);
        }

        return customer;
    }
}
