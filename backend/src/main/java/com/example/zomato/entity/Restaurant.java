package com.example.zomato.entity;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;

@Entity
@Table(name = "restaurant")
public class Restaurant {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "restaurant_id")
    private int id;

    @NotBlank(message = "Restaurant name is required")
    @Column(name = "name", nullable = false)
    private String name;

    @Column(name = "address")
    private String address;

    @ManyToOne
    @JoinColumn(name = "location_id")
    private Location location;

    @ManyToOne
    @JoinColumn(name = "owner_id")
    private RestaurantOwner owner;

    @Column(name = "rating")
    private Float rating;

    @JsonProperty("open")
    @Column(name = "is_open")
    private Boolean isOpen;

    @Column(name = "opening_hours")
    private String openingHours;

    @Column(name = "delivery_time")
    private Integer deliveryTime;

    @Column(name = "image_url")
    private String imageUrl;

    @Column(name = "cuisine")
    private String cuisine;

    @Column(name = "discount")
    private String discount;

    public Restaurant() {}

    public Restaurant(String name, String address, Location location, RestaurantOwner owner,
                      Float rating, Boolean isOpen, String openingHours, Integer deliveryTime) {
        this.name = name;
        this.address = address;
        this.location = location;
        this.owner = owner;
        this.rating = rating;
        this.isOpen = isOpen;
        this.openingHours = openingHours;
        this.deliveryTime = deliveryTime;
    }

    public int getId() { return id; }
    public void setId(int id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getAddress() { return address; }
    public void setAddress(String address) { this.address = address; }

    public Location getLocation() { return location; }
    public void setLocation(Location location) { this.location = location; }

    public RestaurantOwner getOwner() { return owner; }
    public void setOwner(RestaurantOwner owner) { this.owner = owner; }

    public Float getRating() { return rating; }
    public void setRating(Float rating) { this.rating = rating; }

    public Boolean getOpen() { return isOpen; }
    public void setOpen(Boolean open) { this.isOpen = open; }

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
}
