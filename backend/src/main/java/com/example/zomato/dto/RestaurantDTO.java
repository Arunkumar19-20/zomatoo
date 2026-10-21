package com.example.zomato.dto;

import com.example.zomato.entity.Restaurant;

public class RestaurantDTO {
    private Integer id;
    private String name;
    private String address;
    private Float rating;
    private Boolean open;
    private String openingHours;
    private Integer deliveryTime;
    private String imageUrl;
    private String cuisine;
    private String discount;
    private Integer locationId;
    private String locationCity;

    public RestaurantDTO() {}

    public RestaurantDTO(Restaurant r) {
        if (r != null) {
            this.id = r.getId();
            this.name = r.getName();
            this.address = r.getAddress();
            this.rating = r.getRating();
            this.open = r.getOpen();
            this.openingHours = r.getOpeningHours();
            this.deliveryTime = r.getDeliveryTime();
            this.imageUrl = r.getImageUrl();
            this.cuisine = r.getCuisine();
            this.discount = r.getDiscount();
            if (r.getLocation() != null) {
                this.locationId = r.getLocation().getId();
                this.locationCity = r.getLocation().getCity();
            }
        }
    }

    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getAddress() { return address; }
    public void setAddress(String address) { this.address = address; }

    public Float getRating() { return rating; }
    public void setRating(Float rating) { this.rating = rating; }

    public Boolean getOpen() { return open; }
    public void setOpen(Boolean open) { this.open = open; }

    public String getOpeningHours() { return openingHours; }
    public void setOpeningHours(String openingHours) { this.openingHours = openingHours; }

    public Integer getDeliveryTime() { return deliveryTime; }
    public void setDeliveryTime(Integer deliveryTime) { this.deliveryTime = deliveryTime; }

    public String getImageUrl() { return imageUrl; }
    public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }

    public String getCuisine() { return cuisine; }
    public void setCuisine(String cuisine) { this.cuisine = cuisine; }

    public String getDiscount() { return discount; }
    public void setDiscount(String discount) { this.discount = discount; }

    public Integer getLocationId() { return locationId; }
    public void setLocationId(Integer locationId) { this.locationId = locationId; }

    public String getLocationCity() { return locationCity; }
    public void setLocationCity(String locationCity) { this.locationCity = locationCity; }
}
