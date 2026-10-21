package com.example.zomato.entity;

import jakarta.persistence.*;

@Entity
@Table(name = "delivery_partner")
public class DeliveryPartner {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id;

    private String vehicleType;

    private String vehicleNumber;

    private String email;

    private boolean isAvailable;

    private float rating;

    @ManyToOne
    @JoinColumn(name = "location_id")
    private Location currentLocation;

    // Constructors
    public DeliveryPartner() {
    }

    public DeliveryPartner(String vehicleType, String vehicleNumber, boolean isAvailable, float rating, Location currentLocation) {
        this.vehicleType = vehicleType;
        this.vehicleNumber = vehicleNumber;
        this.isAvailable = isAvailable;
        this.rating = rating;
        this.currentLocation = currentLocation;
    }

    // Getters and Setters

    public int getId() {
        return id;
    }

    public void setId(int id) {
        this.id = id;
    }


    public String getVehicleType() {
        return vehicleType;
    }

    public void setVehicleType(String vehicleType) {
        this.vehicleType = vehicleType;
    }


    public String getVehicleNumber() {
        return vehicleNumber;
    }

    public void setVehicleNumber(String vehicleNumber) {
        this.vehicleNumber = vehicleNumber;
    }


    public boolean isAvailable() {
        return isAvailable;
    }

    public void setAvailable(boolean available) {
        isAvailable = available;
    }


    public float getRating() {
        return rating;
    }

    public void setRating(float rating) {
        this.rating = rating;
    }


    public Location getCurrentLocation() {
        return currentLocation;
    }

    public void setCurrentLocation(Location currentLocation) {
        this.currentLocation = currentLocation;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }
}