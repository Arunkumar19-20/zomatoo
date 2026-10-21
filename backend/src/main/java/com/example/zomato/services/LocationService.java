package com.example.zomato.services;

import com.example.zomato.entity.Location;
import com.example.zomato.repository.LocationRepository;

import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class LocationService {

    private final LocationRepository repository;

    public LocationService(LocationRepository repository) {
        this.repository = repository;
    }

    public Location create(Location location) {
        return repository.save(location);
    }

    public List<Location> getAll() {
        return repository.findAll();
    }

    public Location getById(int id) {
        return repository.findById(id)
                .orElseThrow(() -> new RuntimeException("Location not found with id: " + id));
    }

    public Location update(int id, Location updated) {
        Location existing = repository.findById(id)
                .orElseThrow(() -> new RuntimeException("Location not found with id: " + id));
        existing.setAddress(updated.getAddress());
        existing.setCity(updated.getCity());
        existing.setState(updated.getState());
        existing.setZipCode(updated.getZipCode());
        existing.setLatitude(updated.getLatitude());
        existing.setLongitude(updated.getLongitude());
        return repository.save(existing);
    }

    public void delete(int id) {
        repository.deleteById(id);
    }
}
