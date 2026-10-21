package com.example.zomato.dto;

import com.example.zomato.entity.MenuItem;

public class MenuItemDTO {
    private Integer id;
    private String name;
    private String description;
    private Float price;
    private Boolean isVeg;
    private Boolean isAvailable;
    private String imageUrl;
    private Integer categoryId;
    private String categoryName;
    private Integer restaurantId;
    private String restaurantName;

    public MenuItemDTO() {}

    public MenuItemDTO(MenuItem item) {
        if (item != null) {
            this.id = item.getId();
            this.name = item.getName();
            this.description = item.getDescription();
            this.price = item.getPrice();
            this.isVeg = item.getIsVeg();
            this.isAvailable = item.getIsAvailable();
            this.imageUrl = item.getImageUrl();
            if (item.getCategory() != null) {
                this.categoryId = item.getCategory().getId();
                this.categoryName = item.getCategory().getName();
                if (item.getCategory().getRestaurant() != null) {
                    this.restaurantId = item.getCategory().getRestaurant().getId();
                    this.restaurantName = item.getCategory().getRestaurant().getName();
                }
            }
        }
    }

    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public Float getPrice() { return price; }
    public void setPrice(Float price) { this.price = price; }

    public Boolean getIsVeg() { return isVeg; }
    public void setIsVeg(Boolean isVeg) { this.isVeg = isVeg; }

    public Boolean getIsAvailable() { return isAvailable; }
    public void setIsAvailable(Boolean isAvailable) { this.isAvailable = isAvailable; }

    public String getImageUrl() { return imageUrl; }
    public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }

    public Integer getCategoryId() { return categoryId; }
    public void setCategoryId(Integer categoryId) { this.categoryId = categoryId; }

    public String getCategoryName() { return categoryName; }
    public void setCategoryName(String categoryName) { this.categoryName = categoryName; }

    public Integer getRestaurantId() { return restaurantId; }
    public void setRestaurantId(Integer restaurantId) { this.restaurantId = restaurantId; }

    public String getRestaurantName() { return restaurantName; }
    public void setRestaurantName(String restaurantName) { this.restaurantName = restaurantName; }
}
