package com.example.zomato.dto;

import com.example.zomato.entity.Order;
import com.example.zomato.entity.PaymentStatus;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

public class OrderResponseDTO {
    private int orderId;
    private String status;
    private PaymentStatus paymentStatus;
    private LocalDateTime orderDate;
    private float totalAmount;
    private Integer restaurantId;
    private String restaurantName;
    private String restaurantAddress;
    private String restaurantImageUrl;
    private String customerName;
    private String customerEmail;
    private List<OrderItemDTO> items = new ArrayList<>();

    public OrderResponseDTO() {}

    public OrderResponseDTO(Order order) {
        if (order != null) {
            this.orderId = order.getOrderId();
            this.status = order.getStatus();
            this.paymentStatus = order.getPaymentStatus();
            this.orderDate = order.getOrderDate();
            this.totalAmount = order.getTotalAmount();
            if (order.getRestaurant() != null) {
                this.restaurantId = order.getRestaurant().getId();
                this.restaurantName = order.getRestaurant().getName();
                this.restaurantAddress = order.getRestaurant().getAddress();
                this.restaurantImageUrl = order.getRestaurant().getImageUrl();
            }
            if (order.getCustomer() != null) {
                this.customerName = order.getCustomer().getName();
                this.customerEmail = order.getCustomer().getEmail();
            }
            if (order.getOrderItems() != null) {
                this.items = order.getOrderItems().stream().map(OrderItemDTO::new).toList();
            }
        }
    }

    public int getOrderId() { return orderId; }
    public void setOrderId(int orderId) { this.orderId = orderId; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public PaymentStatus getPaymentStatus() { return paymentStatus; }
    public void setPaymentStatus(PaymentStatus paymentStatus) { this.paymentStatus = paymentStatus; }

    public LocalDateTime getOrderDate() { return orderDate; }
    public void setOrderDate(LocalDateTime orderDate) { this.orderDate = orderDate; }

    public float getTotalAmount() { return totalAmount; }
    public void setTotalAmount(float totalAmount) { this.totalAmount = totalAmount; }

    public Integer getRestaurantId() { return restaurantId; }
    public void setRestaurantId(Integer restaurantId) { this.restaurantId = restaurantId; }

    public String getRestaurantName() { return restaurantName; }
    public void setRestaurantName(String restaurantName) { this.restaurantName = restaurantName; }

    public String getRestaurantAddress() { return restaurantAddress; }
    public void setRestaurantAddress(String restaurantAddress) { this.restaurantAddress = restaurantAddress; }

    public String getRestaurantImageUrl() { return restaurantImageUrl; }
    public void setRestaurantImageUrl(String restaurantImageUrl) { this.restaurantImageUrl = restaurantImageUrl; }

    public String getCustomerName() { return customerName; }
    public void setCustomerName(String customerName) { this.customerName = customerName; }

    public String getCustomerEmail() { return customerEmail; }
    public void setCustomerEmail(String customerEmail) { this.customerEmail = customerEmail; }

    public List<OrderItemDTO> getItems() { return items; }
    public void setItems(List<OrderItemDTO> items) { this.items = items; }
}
