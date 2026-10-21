package com.example.zomato.dto;

import com.example.zomato.entity.Cart;
import com.example.zomato.entity.CartItem;

import java.util.ArrayList;
import java.util.List;

public class CartResponseDTO {
    private Integer cartId;
    private Integer customerId;
    private String customerEmail;
    private Integer restaurantId;
    private String restaurantName;
    private Double totalAmount;
    private List<CartItemDTO> items = new ArrayList<>();

    public CartResponseDTO() {}

    public CartResponseDTO(Cart cart, List<CartItem> cartItems) {
        if (cart != null) {
            this.cartId = cart.getId();
            if (cart.getCustomer() != null) {
                this.customerId = cart.getCustomer().getCustomerId();
                this.customerEmail = cart.getCustomer().getEmail();
            }
            if (cart.getRestaurant() != null) {
                this.restaurantId = cart.getRestaurant().getId();
                this.restaurantName = cart.getRestaurant().getName();
            }
        }
        if (cartItems != null) {
            this.items = cartItems.stream().map(CartItemDTO::new).toList();
            this.totalAmount = this.items.stream().mapToDouble(CartItemDTO::getSubtotal).sum();
            if (this.restaurantId == null && !cartItems.isEmpty() && cartItems.get(0).getItem() != null
                    && cartItems.get(0).getItem().getCategory() != null
                    && cartItems.get(0).getItem().getCategory().getRestaurant() != null) {
                this.restaurantId = cartItems.get(0).getItem().getCategory().getRestaurant().getId();
                this.restaurantName = cartItems.get(0).getItem().getCategory().getRestaurant().getName();
            }
        } else {
            this.totalAmount = 0.0;
        }
    }

    public Integer getCartId() { return cartId; }
    public void setCartId(Integer cartId) { this.cartId = cartId; }

    public Integer getCustomerId() { return customerId; }
    public void setCustomerId(Integer customerId) { this.customerId = customerId; }

    public String getCustomerEmail() { return customerEmail; }
    public void setCustomerEmail(String customerEmail) { this.customerEmail = customerEmail; }

    public Integer getRestaurantId() { return restaurantId; }
    public void setRestaurantId(Integer restaurantId) { this.restaurantId = restaurantId; }

    public String getRestaurantName() { return restaurantName; }
    public void setRestaurantName(String restaurantName) { this.restaurantName = restaurantName; }

    public Double getTotalAmount() { return totalAmount; }
    public void setTotalAmount(Double totalAmount) { this.totalAmount = totalAmount; }

    public List<CartItemDTO> getItems() { return items; }
    public void setItems(List<CartItemDTO> items) { this.items = items; }
}
