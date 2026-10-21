package com.example.zomato.dto;

import com.example.zomato.entity.CartItem;

public class CartItemDTO {
    private Integer id;
    private Integer itemId;
    private String name;
    private Double price;
    private Integer quantity;
    private Double subtotal;
    private String imageUrl;
    private Boolean isVeg;

    public CartItemDTO() {}

    public CartItemDTO(CartItem item) {
        if (item != null) {
            this.id = item.getId();
            this.price = item.getPrice();
            this.quantity = item.getQuantity();
            this.subtotal = (item.getPrice() != null && item.getQuantity() != null)
                    ? item.getPrice() * item.getQuantity() : 0.0;
            if (item.getItem() != null) {
                this.itemId = item.getItem().getId();
                this.name = item.getItem().getName();
                this.imageUrl = item.getItem().getImageUrl();
                this.isVeg = item.getItem().getIsVeg();
            }
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

    public Boolean getIsVeg() { return isVeg; }
    public void setIsVeg(Boolean isVeg) { this.isVeg = isVeg; }
}
