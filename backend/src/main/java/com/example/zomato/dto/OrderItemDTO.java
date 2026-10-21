package com.example.zomato.dto;

import com.example.zomato.entity.OrderItem;

public class OrderItemDTO {
    private Integer id;
    private Integer itemId;
    private String name;
    private Double price;
    private Integer quantity;
    private Double subtotal;
    private String imageUrl;

    public OrderItemDTO() {}

    public OrderItemDTO(OrderItem item) {
        if (item != null) {
            this.id = item.getOrderItemId();
            if (item.getCustomName() != null && !item.getCustomName().isBlank()) {
                this.name = item.getCustomName();
            } else if (item.getItem() != null) {
                this.name = item.getItem().getName();
            }
            if (item.getItem() != null) {
                this.itemId = item.getItem().getId();
                this.imageUrl = item.getItem().getImageUrl();
            }
            this.price = item.getPrice();
            this.quantity = item.getQuantity();
            this.subtotal = item.calculateSubtotal();
        }
    }

    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }

    public Integer getItemId() { return itemId; }
    public void setItemId(Integer itemId) { this.itemId = itemId; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public Double getPrice() { return price; }
    public void setPrice(Double price) { this.price = price; }

    public Integer getQuantity() { return quantity; }
    public void setQuantity(Integer quantity) { this.quantity = quantity; }

    public Double getSubtotal() { return subtotal; }
    public void setSubtotal(Double subtotal) { this.subtotal = subtotal; }

    public String getImageUrl() { return imageUrl; }
    public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }
}
