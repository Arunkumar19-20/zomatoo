package com.example.zomato.controller;

import com.example.zomato.entity.Location;
import com.example.zomato.services.LocationService;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/locations")
public class LocationController {

    private final LocationService service;

    public LocationController(LocationService service) {
        this.service = service;
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping
    public Location create(@RequestBody Location location) {
        return service.create(location);
    }

    @GetMapping
    public List<Location> getAll() {
        return service.getAll();
    }

    @GetMapping("/{id}")
    public Location getById(@PathVariable int id) {
        return service.getById(id);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PutMapping("/{id}")
    public Location update(@PathVariable int id, @RequestBody Location location) {
        return service.update(id, location);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @DeleteMapping("/{id}")
    public void delete(@PathVariable int id) {
        service.delete(id);
    }
}

